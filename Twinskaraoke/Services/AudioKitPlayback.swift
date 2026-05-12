import AVFoundation
import AudioKit
import Combine
import Foundation

@MainActor
final class AudioKitPlayback {
  enum Mode { case single, aiMix }

  /// Volume ramp shape used during crossfade.
  enum RampStyle {
    case equalPower  // cos/sin curve — constant perceived loudness
    case linear      // straight line — faster cuts
  }

  let engine = AudioEngine()
  let mainPlayer = AudioPlayer()
  let auxPlayer = AudioPlayer()
  /// Dedicated player for crossfade transitions (separate from auxPlayer,
  /// which is reserved for AI vocal separation).
  let crossfadePlayer = AudioPlayer()
  private let mixer: Mixer
  let userEQ = AVAudioUnitEQ(numberOfBands: 10)
  let bassEQ = AVAudioUnitEQ(numberOfBands: 1)

  private(set) var mode: Mode = .single
  private(set) var currentURL: URL?
  private(set) var auxURL: URL?
  private(set) var aiVocalsStrength: Float = 1.0
  private(set) var aiStartOffset: TimeInterval = 0

  /// Monotonically increasing token bumped before any intentional stop/swap/seek.
  /// The completion handler captures the current value; if it has changed by the
  /// time the async dispatch runs, the callback is stale and is discarded.
  /// This eliminates the race where `DispatchQueue.main.async` runs *after*
  /// the old Bool flag was already reset to `false`.
  private var suppressionToken: UInt64 = 0

  // MARK: - Crossfade state

  /// Whether a crossfade is currently in progress.
  private(set) var isCrossfading = false

  /// Timer driving the volume ramp at ~60 Hz during crossfade.
  private var crossfadeTimer: Timer?

  /// Total duration of the active crossfade.
  private var crossfadeDuration: TimeInterval = 0

  /// Elapsed time since the crossfade started.
  private var crossfadeElapsed: TimeInterval = 0

  /// Ramp shape for the active crossfade.
  private var crossfadeRamp: RampStyle = .equalPower

  /// Called when the crossfade finishes (incoming song is fully playing).
  var onCrossfadeCompleted: (() -> Void)?

  var onPlaybackEnded: (() -> Void)?
  var onPlaybackError: ((Error) -> Void)?

  static let eqBandCount = 10
  static let bandFrequencies: [Float] = [
    31.5, 63, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000,
  ]

  init() {
    mixer = Mixer(mainPlayer, auxPlayer, crossfadePlayer)
    auxPlayer.volume = 0
    crossfadePlayer.volume = 0

    for i in 0..<10 {
      let band = userEQ.bands[i]
      band.filterType = .parametric
      band.frequency = AudioKitPlayback.bandFrequencies[i]
      band.bandwidth = 1.0
      band.gain = 0
      band.bypass = false
    }
    userEQ.bypass = true

    let bassBand = bassEQ.bands[0]
    bassBand.filterType = .lowShelf
    bassBand.frequency = 250
    bassBand.bandwidth = 1.0
    bassBand.gain = 0
    bassBand.bypass = true
    bassEQ.bypass = true

    // Audio graph: mixer → bassEQ → userEQ → engine.output
    let bassNode = AVAudioUnitWrapperNode(input: mixer, unit: bassEQ)
    let userNode = AVAudioUnitWrapperNode(input: bassNode, unit: userEQ)
    engine.output = userNode

    mainPlayer.completionHandler = { [weak self] in
      guard let self else { return }
      let token = self.suppressionToken
      DispatchQueue.main.async {
        // If the token changed, a stop/seek/swap happened after this
        // completion was enqueued — discard the stale callback.
        guard self.suppressionToken == token else { return }
        self.onPlaybackEnded?()
      }
    }

    do { try engine.start() } catch {
      onPlaybackError?(error)
    }
  }

  func startEngineIfNeeded() {
    if !engine.avEngine.isRunning {
      do { try engine.start() } catch { onPlaybackError?(error) }
    }
  }

  // MARK: - Audio header validation

  /// Returns true if the file at `url` starts with a recognisable audio header
  /// (MP3 sync word, ID3 tag, RIFF/WAVE, CAF, AIFF, or FLAC).  Returns false
  /// for truncated / empty / unrecognisable files — callers should skip
  /// AVAudioFile and go straight to AVAssetReader to avoid Core Audio console spam.
  static func hasValidAudioHeader(at url: URL) -> Bool {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
    defer { try? handle.close() }
    guard let header = try? handle.read(upToCount: 12), header.count >= 4 else { return false }
    // MP3 frame sync (0xFF followed by 0xE0 mask)
    if header[0] == 0xFF && (header[1] & 0xE0) == 0xE0 { return true }
    // ID3v2 tag
    if header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33 { return true }
    // RIFF/WAVE
    if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
      return true
    }
    // AIFF
    if header[0] == 0x46 && header[1] == 0x4F && header[2] == 0x52 && header[3] == 0x4D {
      return true
    }
    // CAF
    if header[0] == 0x63 && header[1] == 0x61 && header[2] == 0x66 && header[3] == 0x66 {
      return true
    }
    // FLAC
    if header[0] == 0x66 && header[1] == 0x4C && header[2] == 0x61 && header[3] == 0x43 {
      return true
    }
    return false
  }

  // MARK: - File loading with MP3 fallback

  private func loadIntoPlayer(_ player: AudioPlayer, url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw NSError(
        domain: NSOSStatusErrorDomain, code: 1685348671,
        userInfo: [NSLocalizedDescriptionKey: "Audio file not found: \(url.lastPathComponent)"])
    }
    // Skip AVAudioFile for clearly invalid files (empty / truncated) to
    // avoid Core Audio console errors.  For anything with a recognisable
    // header we still try AVAudioFile first since it handles the widest
    // range of codec edge-cases.
    let headerOK = AudioKitPlayback.hasValidAudioHeader(at: url)
    if headerOK {
      if let file = try? AVAudioFile(forReading: url) {
        if file.processingFormat.channelCount == 2 {
          try player.load(file: file)
          return
        }
        // Mono file — convert to stereo buffer before loading
        if let stereo = AudioKitPlayback.convertToStereo(file: file) {
          player.load(buffer: stereo)
          return
        }
      }
      if let file = try? AVAudioFile(
        forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
      {
        if file.processingFormat.channelCount == 2 {
          try player.load(file: file)
          return
        }
        if let stereo = AudioKitPlayback.convertToStereo(file: file) {
          player.load(buffer: stereo)
          return
        }
      }
    }
    if let buffer = AudioKitPlayback.decodeFileToBuffer(url: url) {
      player.load(buffer: buffer)
      return
    }
    // Last resort: try AVAudioFile regardless of header check — let
    // Core Audio log its diagnostics if this also fails.
    let file = try AVAudioFile(forReading: url)
    try player.load(file: file)
  }

  static func decodeFileToBuffer(url: URL) -> AVAudioPCMBuffer? {
    let asset = AVURLAsset(url: url)
    let tracks = asset.tracks(withMediaType: .audio)
    guard let track = tracks.first else { return nil }
    guard let reader = try? AVAssetReader(asset: asset) else { return nil }
    let sampleRate: Double = 44100
    let outputSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: 2,
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: true,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
    reader.add(output)
    guard reader.startReading() else { return nil }
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
        channels: 2, interleaved: false)
    else { return nil }
    let totalFrames = AVAudioFrameCount(max(1, asset.duration.seconds * sampleRate) + 8192)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)
    else { return nil }
    buffer.frameLength = 0
    while reader.status == .reading {
      guard let sb = output.copyNextSampleBuffer(), let bb = CMSampleBufferGetDataBuffer(sb)
      else { break }
      let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sb))
      var length = 0
      var dataPtr: UnsafeMutablePointer<Int8>?
      if CMBlockBufferGetDataPointer(
        bb, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length,
        dataPointerOut: &dataPtr) != noErr
      {
        continue
      }
      guard let dataPtr else { continue }
      let writeStart = buffer.frameLength
      let writeEnd = writeStart + frames
      if writeEnd > buffer.frameCapacity { break }
      let perChannelBytes = Int(frames) * MemoryLayout<Float>.size
      if let channelData = buffer.floatChannelData {
        memcpy(
          channelData[0].advanced(by: Int(writeStart)),
          dataPtr, perChannelBytes)
        if length >= perChannelBytes * 2 {
          memcpy(
            channelData[1].advanced(by: Int(writeStart)),
            dataPtr.advanced(by: perChannelBytes), perChannelBytes)
        }
      }
      buffer.frameLength = writeEnd
    }
    if reader.status == .failed { return nil }
    return buffer.frameLength > 0 ? buffer : nil
  }

  // MARK: - Mono → Stereo conversion

  /// Reads a mono AVAudioFile into a stereo PCM buffer (duplicates the channel).
  private static func convertToStereo(file: AVAudioFile) -> AVAudioPCMBuffer? {
    let srcFormat = file.processingFormat
    guard srcFormat.channelCount == 1 else { return nil }
    let frameCount = AVAudioFrameCount(file.length)
    guard frameCount > 0 else { return nil }
    // Read the mono data
    guard let monoBuf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount)
    else { return nil }
    do { try file.read(into: monoBuf) } catch { return nil }
    return monoToStereo(monoBuf)
  }

  /// Returns nil when the buffer is already stereo (no work needed).
  /// Returns a new stereo buffer with the mono channel duplicated into L+R.
  static func ensureStereo(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard buffer.format.channelCount == 1 else { return nil }
    return monoToStereo(buffer)
  }

  private static func monoToStereo(_ mono: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    let frames = mono.frameLength
    guard frames > 0,
      let stereoFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: mono.format.sampleRate,
        channels: 2, interleaved: false),
      let stereo = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: frames)
    else { return nil }
    stereo.frameLength = frames
    guard let monoData = mono.floatChannelData?[0],
      let leftData = stereo.floatChannelData?[0],
      let rightData = stereo.floatChannelData?[1]
    else { return nil }
    let byteCount = Int(frames) * MemoryLayout<Float>.size
    memcpy(leftData, monoData, byteCount)
    memcpy(rightData, monoData, byteCount)
    return stereo
  }

  // MARK: - Playback

  private func safeStart(_ startAt: TimeInterval, durations: TimeInterval...) -> TimeInterval? {
    guard startAt > 0.05, startAt.isFinite else { return nil }
    let validDurations = durations.filter { $0.isFinite && $0 > 0 }
    guard let limit = validDurations.min() else { return nil }
    let capped = limit - 0.25
    guard capped > 0.05, startAt < capped else { return nil }
    return startAt
  }

  func play(url: URL, startAt: TimeInterval = 0) {
    do {
      suppressionToken &+= 1
      mainPlayer.stop()
      try loadIntoPlayer(mainPlayer, url: url)
      currentURL = url
      mode = .single
      auxURL = nil
      aiStartOffset = 0
      auxPlayer.stop()
      auxPlayer.volume = 0
      mainPlayer.volume = 1
      resetBassEQ()
      startEngineIfNeeded()
      let from = safeStart(startAt, durations: mainPlayer.duration)
      mainPlayer.play(from: from)
    } catch {
      onPlaybackError?(error)
    }
  }

  func playAI(
    instrumental: URL, vocals: URL, vocalsStrength: Float,
    startOffset: TimeInterval = 0, startAt: TimeInterval = 0
  ) {
    do {
      suppressionToken &+= 1
      mainPlayer.stop()
      auxPlayer.stop()
      try loadIntoPlayer(mainPlayer, url: instrumental)
      try loadIntoPlayer(auxPlayer, url: vocals)
      currentURL = instrumental
      auxURL = vocals
      aiVocalsStrength = max(0, min(1, vocalsStrength))
      aiStartOffset = max(0, startOffset)
      mode = .aiMix
      mainPlayer.volume = 1.0
      auxPlayer.volume = AUValue(max(0, min(1, 1 - aiVocalsStrength)))
      startEngineIfNeeded()
      let from = safeStart(startAt, durations: mainPlayer.duration, auxPlayer.duration)
      mainPlayer.play(from: from)
      auxPlayer.play(from: from)
      auxPlayer.volume = AUValue(max(0, min(1, 1 - aiVocalsStrength)))
    } catch {
      onPlaybackError?(error)
    }
  }

  func playAIBuffers(
    instrumental: AVAudioPCMBuffer, vocals: AVAudioPCMBuffer?,
    startOffset: TimeInterval = 0, startAt: TimeInterval = 0
  ) {
    suppressionToken &+= 1
    mainPlayer.stop()
    auxPlayer.stop()
    let stereoInstr = AudioKitPlayback.ensureStereo(instrumental) ?? instrumental
    mainPlayer.load(buffer: stereoInstr)
    if let vocals {
      let stereoVocals = AudioKitPlayback.ensureStereo(vocals) ?? vocals
      auxPlayer.load(buffer: stereoVocals)
    }
    currentURL = nil
    auxURL = nil
    aiStartOffset = max(0, startOffset)
    mode = .aiMix
    // Volumes are set by the caller via applyAIMixVolumes() after this method returns.
    // Default both to 1.0 so the caller's settings take effect cleanly.
    mainPlayer.volume = 1.0
    auxPlayer.volume = 1.0
    startEngineIfNeeded()
    let from = safeStart(startAt, durations: mainPlayer.duration, auxPlayer.duration)
    mainPlayer.play(from: from)
    if vocals != nil { auxPlayer.play(from: from) }
  }

  func setAIVocalStrength(_ s: Float) {
    aiVocalsStrength = max(0, min(1, s))
    if mode == .aiMix {
      auxPlayer.volume = AUValue(max(0, min(1, 1 - aiVocalsStrength)))
    }
  }

  var currentTime: TimeInterval {
    if mode == .aiMix {
      return aiStartOffset + mainPlayer.currentTime
    }
    return mainPlayer.currentTime
  }

  var duration: TimeInterval {
    if mode == .aiMix, mainPlayer.duration.isFinite, mainPlayer.duration > 0 {
      return aiStartOffset + mainPlayer.duration
    }
    return mainPlayer.duration
  }

  var isPlaying: Bool { mainPlayer.isPlaying }

  func pause() {
    mainPlayer.pause()
    if mode == .aiMix { auxPlayer.pause() }
  }

  func resume() {
    startEngineIfNeeded()
    mainPlayer.play()
    if mode == .aiMix { auxPlayer.play() }
  }

  func stop() {
    suppressionToken &+= 1
    mainPlayer.stop()
    auxPlayer.stop()
    currentURL = nil
    auxURL = nil
    aiStartOffset = 0
    mode = .single
    resetBassEQ()
  }

  @discardableResult
  func seek(to seconds: TimeInterval) -> Bool {
    guard seconds.isFinite else { return true }
    if mode == .aiMix {
      let aiTarget = seconds - aiStartOffset
      if aiTarget < 0 { return false }
      let dur = mainPlayer.duration
      guard dur.isFinite, dur > 0 else { return true }
      let upper = dur - 0.5
      guard upper > 0 else { return true }
      let target = max(0, min(aiTarget, upper))
      suppressionToken &+= 1
      let delta = target - mainPlayer.currentTime
      if abs(delta) > 0.01 { mainPlayer.seek(time: delta) }
      let auxDelta = target - auxPlayer.currentTime
      if abs(auxDelta) > 0.01 { auxPlayer.seek(time: auxDelta) }
      return true
    }
    let dur = mainPlayer.duration
    guard dur.isFinite, dur > 0 else { return true }
    let upper = dur - 0.5
    guard upper > 0 else { return true }
    let target = max(0, min(seconds, upper))
    suppressionToken &+= 1
    let delta = target - mainPlayer.currentTime
    if abs(delta) > 0.01 { mainPlayer.seek(time: delta) }
    return true
  }

  // MARK: - EQ

  func setEQEnabled(_ on: Bool) { userEQ.bypass = !on }

  func setEQGains(_ gains: [Float]) {
    for i in 0..<min(gains.count, userEQ.bands.count) {
      userEQ.bands[i].gain = gains[i]
    }
  }

  // MARK: - Bass EQ (for AI bass enhance on instrumental)

  func setBassEQGain(dB: Float) {
    let band = bassEQ.bands[0]
    band.gain = dB
    let active = dB > 0.01
    band.bypass = !active
    bassEQ.bypass = !active
  }

  func resetBassEQ() {
    setBassEQGain(dB: 0)
  }

  // MARK: - AI mix volume control

  func setMainPlayerVolume(_ v: Float) {
    mainPlayer.volume = AUValue(max(0, min(2, v)))
  }

  func setAuxPlayerVolume(_ v: Float) {
    auxPlayer.volume = AUValue(max(0, min(2, v)))
  }

  func setMasterVolume(_ v: Float) {
    mixer.volume = AUValue(max(0, min(1, v)))
  }

  // MARK: - Crossfade engine

  /// Pre-load the next song into `crossfadePlayer` ahead of the actual crossfade.
  /// Called by TransitionCoordinator when the plan is ready (~seconds before trigger).
  func preloadCrossfade(url: URL) {
    // Don't preload if a crossfade is already in progress.
    guard !isCrossfading else { return }
    do {
      try loadIntoPlayer(crossfadePlayer, url: url)
      preloadedCrossfadeURL = url
      crossfadePlayer.volume = 0
    } catch {
      preloadedCrossfadeURL = nil
    }
  }

  /// Load the next song into `crossfadePlayer` and begin an equal-power
  /// (or linear) volume ramp over `duration` seconds.
  ///
  /// While the crossfade is active the `mainPlayer` volume ramps down and
  /// `crossfadePlayer` ramps up.  When done, `finalizeCrossfade()` swaps
  /// the content into `mainPlayer` so subsequent operations are unaffected.
  func beginCrossfade(url: URL, duration: TimeInterval, ramp: RampStyle) {
    // Check if we already pre-loaded this exact file.
    let alreadyPreloaded = (preloadedCrossfadeURL == url)

    // Cancel any existing crossfade but preserve the crossfadePlayer if preloaded.
    crossfadeTimer?.invalidate()
    crossfadeTimer = nil
    preloadedCrossfadeURL = nil
    if isCrossfading {
      isCrossfading = false
      if !alreadyPreloaded {
        crossfadePlayer.stop()
        crossfadePlayer.volume = 0
      }
      if mode != .aiMix {
        mainPlayer.volume = 1.0
      }
    }

    // Load if not already preloaded.
    if !alreadyPreloaded {
      do {
        try loadIntoPlayer(crossfadePlayer, url: url)
      } catch {
        onPlaybackError?(error)
        return
      }
    }
    crossfadeDuration = max(0.5, duration)
    crossfadeElapsed = 0
    crossfadeRamp = ramp
    isCrossfading = true
    pendingCrossfadeURL = url

    // Capture the current outgoing volumes for AI mix mode so the ramp
    // uses absolute values instead of compounding multiplicatively.
    crossfadeStartMainVol = Float(mainPlayer.volume)
    crossfadeStartAuxVol = Float(auxPlayer.volume)

    crossfadePlayer.volume = 0
    startEngineIfNeeded()
    crossfadePlayer.play()

    // 60 Hz ramp timer
    let interval: TimeInterval = 1.0 / 60.0
    crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] timer in
      guard let self else { timer.invalidate(); return }
      self.crossfadeElapsed += interval
      let t = Float(min(1.0, self.crossfadeElapsed / self.crossfadeDuration))

      let outVol: Float
      let inVol: Float
      switch self.crossfadeRamp {
      case .equalPower:
        // cos/sin equal-power curve: out² + in² ≈ 1.0 at midpoint
        outVol = cos(t * .pi / 2)
        inVol = sin(t * .pi / 2)
      case .linear:
        outVol = 1.0 - t
        inVol = t
      }

      if self.mode == .aiMix {
        // AI mix uses both mainPlayer and auxPlayer — scale both down using
        // the absolute volumes captured at crossfade start (not multiplicative).
        self.mainPlayer.volume = AUValue(max(0, self.crossfadeStartMainVol * outVol))
        self.auxPlayer.volume = AUValue(max(0, self.crossfadeStartAuxVol * outVol))
      } else {
        self.mainPlayer.volume = AUValue(max(0, outVol))
      }
      self.crossfadePlayer.volume = AUValue(max(0, inVol))

      if t >= 1.0 {
        self.finalizeCrossfade()
      }
    }
  }

  /// Cancel an in-progress crossfade (e.g. user skipped manually).
  func cancelCrossfade() {
    crossfadeTimer?.invalidate()
    crossfadeTimer = nil
    // Clean up any pre-loaded content.
    preloadedCrossfadeURL = nil
    guard isCrossfading else {
      // Not crossfading — but the crossfadePlayer may have a preloaded file.
      // Stop it to free resources.
      crossfadePlayer.stop()
      crossfadePlayer.volume = 0
      return
    }
    isCrossfading = false
    crossfadePlayer.stop()
    crossfadePlayer.volume = 0
    // Restore outgoing volumes
    if mode == .aiMix {
      // Volumes will be reset by the caller (applyAIMixVolumes).
    } else {
      mainPlayer.volume = 1.0
    }
  }

  /// Crossfade finished — swap incoming content to mainPlayer seamlessly.
  /// The key trick: keep `crossfadePlayer` audible while loading `mainPlayer`,
  /// then stop it only after `mainPlayer` is producing audio.
  private func finalizeCrossfade() {
    crossfadeTimer?.invalidate()
    crossfadeTimer = nil
    isCrossfading = false

    // Stop the outgoing players (already at volume 0).
    suppressionToken &+= 1
    mainPlayer.stop()
    if mode == .aiMix {
      auxPlayer.stop()
    }

    // Keep crossfadePlayer running at full volume to avoid any silence gap.
    crossfadePlayer.volume = 1.0

    if let url = pendingCrossfadeURL {
      do {
        // Record the resume position while crossfadePlayer is still audible.
        let resumeTime = crossfadePlayer.currentTime
        // Load the file into mainPlayer (crossfadePlayer covers audio during I/O).
        try loadIntoPlayer(mainPlayer, url: url)
        mode = .single
        auxURL = nil
        aiStartOffset = 0
        auxPlayer.stop()
        auxPlayer.volume = 0
        mainPlayer.volume = 1.0
        resetBassEQ()
        let from = safeStart(resumeTime, durations: mainPlayer.duration)
        mainPlayer.play(from: from)
        currentURL = url
        // mainPlayer is now producing audio — stop crossfadePlayer.
        crossfadePlayer.stop()
        crossfadePlayer.volume = 0
      } catch {
        // Load failed — stop crossfadePlayer anyway (nothing else we can do).
        crossfadePlayer.stop()
        crossfadePlayer.volume = 0
        onPlaybackError?(error)
      }
    } else {
      crossfadePlayer.stop()
      crossfadePlayer.volume = 0
    }

    pendingCrossfadeURL = nil
    onCrossfadeCompleted?()
  }

  /// URL of the file being crossfaded in — set by `beginCrossfade`, consumed by `finalizeCrossfade`.
  private var pendingCrossfadeURL: URL?

  /// URL pre-loaded into `crossfadePlayer` ahead of the crossfade trigger.
  private var preloadedCrossfadeURL: URL?

  /// Initial outgoing player volumes captured at crossfade start (for AI mix mode).
  private var crossfadeStartMainVol: Float = 1.0
  private var crossfadeStartAuxVol: Float = 0.0
}

final class AVAudioUnitWrapperNode: Node {
  let avAudioNode: AVAudioNode
  let connections: [Node]
  init(input: Node, unit: AVAudioNode) {
    self.avAudioNode = unit
    self.connections = [input]
  }
}
