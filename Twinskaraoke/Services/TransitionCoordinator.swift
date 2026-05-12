import Foundation

/// Orchestrates BPM-based auto-mix and crossfade transitions between songs.
///
/// The coordinator is polled every 0.5 s from `AudioPlayerManager`'s timer.
/// It progresses through states: idle → preparing → ready → crossfading,
/// determining the next song, detecting BPM, pre-downloading audio, and
/// finally triggering the crossfade at the right moment.
@MainActor
final class TransitionCoordinator {

  // MARK: - Types

  enum State {
    case idle
    case preparing(nextSong: Song)
    case ready(plan: TransitionPlan)
    case crossfading(plan: TransitionPlan)

    var isCrossfading: Bool {
      if case .crossfading = self { return true }
      return false
    }
    var isPreparing: Bool {
      if case .preparing = self { return true }
      return false
    }
  }

  struct TransitionPlan {
    let nextSong: Song
    let nextFileURL: URL
    let outgoingBPM: Double?
    let incomingBPM: Double?
    let fadeDuration: TimeInterval
    let rampStyle: AudioKitPlayback.RampStyle
  }

  // MARK: - Properties

  private(set) var state: State = .idle
  private var bpmTask: Task<Void, Never>?
  private var predownloadSession: PredownloadSession?

  /// Weak reference to the audio engine — set during integration.
  weak var audioKit: AudioKitPlayback?

  /// Called when the coordinator wants to start playing the next song
  /// (either crossfade or quick-cut for AI mode).
  var onBeginTransition: ((TransitionPlan) -> Void)?

  /// Called when the coordinator determines the upcoming song (for UI display).
  var onUpcomingSongDetermined: ((Song?) -> Void)?

  // MARK: - Configuration

  /// How far before the end (seconds) to start preparing the next song.
  private let prepareLeadTime: TimeInterval = 30

  /// Minimum lead time for very short songs (fraction of duration).
  private let prepareLeadFraction: Double = 0.5

  // MARK: - BPM cache

  private var bpmCache: [String: Double] = {
    UserDefaults.standard.dictionary(forKey: "nk.bpmCache") as? [String: Double] ?? [:]
  }()

  func cachedBPM(for songID: String) -> Double? {
    bpmCache[songID]
  }

  private func storeBPM(_ bpm: Double, for songID: String) {
    bpmCache[songID] = bpm
    // Persist — cap at 500 entries to avoid unbounded growth.
    if bpmCache.count > 500 {
      let keysToRemove = Array(bpmCache.keys.prefix(bpmCache.count - 500))
      for key in keysToRemove { bpmCache.removeValue(forKey: key) }
    }
    UserDefaults.standard.set(bpmCache, forKey: "nk.bpmCache")
  }

  // MARK: - Poll (called every 0.5 s from AudioPlayerManager)

  func poll(
    currentTime: TimeInterval,
    totalDuration: TimeInterval,
    currentSong: Song?,
    queue: [Song],
    autoMixEnabled: Bool,
    crossfadeEnabled: Bool,
    crossfadeSeconds: Double,
    aiEffectActive: Bool,
    autoplayEnabled: Bool
  ) {
    guard totalDuration > 0, let currentSong else { return }
    guard autoMixEnabled || crossfadeEnabled else {
      if case .idle = state {} else { reset() }
      return
    }

    let remaining = totalDuration - currentTime
    let prepareAt = min(prepareLeadTime, totalDuration * prepareLeadFraction)

    switch state {
    case .idle:
      guard remaining <= prepareAt, remaining > 0 else { return }
      // Determine next song
      if let nextSong = nextSongInQueue(current: currentSong, queue: queue) {
        beginPreparing(
          nextSong: nextSong, currentSong: currentSong,
          autoMixEnabled: autoMixEnabled, crossfadeSeconds: crossfadeSeconds,
          aiEffectActive: aiEffectActive
        )
      }
      // If no next song and autoplay is on, the fallback in playNextOrRandom
      // will fetch a random trending song — we don't interfere.

    case .preparing:
      // Still waiting for BPM detection / pre-download to finish.
      break

    case .ready(let plan):
      // Check if it's time to trigger.
      if remaining <= plan.fadeDuration + 0.5 {
        state = .crossfading(plan: plan)
        onBeginTransition?(plan)
      }

    case .crossfading:
      // Already in progress — nothing to do.
      break
    }
  }

  // MARK: - Preparation

  private func beginPreparing(
    nextSong: Song, currentSong: Song,
    autoMixEnabled: Bool, crossfadeSeconds: Double,
    aiEffectActive: Bool
  ) {
    state = .preparing(nextSong: nextSong)
    onUpcomingSongDetermined?(nextSong)

    bpmTask?.cancel()
    bpmTask = Task { [weak self] in
      guard let self else { return }

      // Detect BPM for both songs concurrently.
      let currentURL = self.audioFileURL(for: currentSong)
      let nextURL = self.audioFileURL(for: nextSong)

      // Start pre-downloading the next song if not cached.
      if nextURL == nil, let remoteURL = nextSong.audioURL {
        await self.predownload(song: nextSong, from: remoteURL)
      }

      async let outBPMResult = self.detectBPM(for: currentSong, fileURL: currentURL)
      let nextFileURL = self.audioFileURL(for: nextSong)
      async let inBPMResult = self.detectBPM(for: nextSong, fileURL: nextFileURL)

      let outBPM = await outBPMResult
      let inBPM = await inBPMResult

      if Task.isCancelled { return }

      // Compute fade parameters.
      let fadeDuration: TimeInterval
      let rampStyle: AudioKitPlayback.RampStyle

      if autoMixEnabled {
        if aiEffectActive {
          // AI effects active — quick cut, no real crossfade.
          fadeDuration = 0.5
          rampStyle = .linear
        } else {
          let result = Self.computeFade(outBPM: outBPM, inBPM: inBPM)
          fadeDuration = result.duration
          rampStyle = result.style
        }
      } else {
        // Crossfade mode — user-configured duration.
        fadeDuration = crossfadeSeconds
        rampStyle = .equalPower
      }

      guard let fileURL = self.audioFileURL(for: nextSong) else {
        // File not available — fall back to normal playNextOrRandom.
        await MainActor.run { [weak self] in self?.reset() }
        return
      }

      let plan = TransitionPlan(
        nextSong: nextSong,
        nextFileURL: fileURL,
        outgoingBPM: outBPM,
        incomingBPM: inBPM,
        fadeDuration: fadeDuration,
        rampStyle: rampStyle
      )

      await MainActor.run { [weak self] in
        guard let self else { return }
        // Make sure we're still preparing the same song.
        guard case .preparing(let s) = self.state, s.id == nextSong.id else { return }
        self.state = .ready(plan: plan)
        // Pre-load the next song into the crossfade player now (seconds
        // before the actual crossfade triggers) so beginCrossfade() can
        // skip the synchronous file I/O entirely.
        self.audioKit?.preloadCrossfade(url: fileURL)
      }
    }
  }

  // MARK: - BPM detection (with cache)

  private func detectBPM(for song: Song, fileURL: URL?) async -> Double? {
    if let cached = bpmCache[song.id] { return cached }
    guard let url = fileURL else { return nil }
    guard let bpm = await BPMDetector.detect(url: url) else { return nil }
    await MainActor.run { [weak self] in
      self?.storeBPM(bpm, for: song.id)
    }
    return bpm
  }

  // MARK: - Tempo-matched blending

  /// Compute fade duration and ramp style from BPM similarity.
  static func computeFade(
    outBPM: Double?, inBPM: Double?
  ) -> (duration: TimeInterval, style: AudioKitPlayback.RampStyle) {
    guard let out = outBPM, let inB = inBPM else {
      return (6.0, .equalPower)  // fallback when BPM unknown
    }
    let diff = harmonicBPMDifference(out, inB)
    if diff <= 8 {
      // Close tempos — long smooth blend, beat-aligned.
      let beatDur = 60.0 / out
      let targetBeats = max(4, (8.0 / beatDur).rounded())
      return (targetBeats * beatDur, .equalPower)
    } else if diff <= 20 {
      // Moderate difference — 4 second blend.
      return (4.0, .equalPower)
    } else {
      // Very different tempos — quick cut.
      return (1.5, .linear)
    }
  }

  /// Harmonic BPM difference accounting for half/double time.
  /// e.g. 70 BPM ≈ 140 BPM (difference = 0, not 70).
  static func harmonicBPMDifference(_ a: Double, _ b: Double) -> Double {
    [b, b * 2, b / 2].map { abs(a - $0) }.min()!
  }

  // MARK: - File resolution

  private func audioFileURL(for song: Song) -> URL? {
    let downloaded = DownloadManager.shared.localURL(for: song.id)
    if FileManager.default.fileExists(atPath: downloaded.path) { return downloaded }
    let cached = AudioPlayerManager.audioCacheDir.appendingPathComponent("\(song.id).mp3")
    if FileManager.default.fileExists(atPath: cached.path) { return cached }
    return nil
  }

  // MARK: - Next song determination

  private func nextSongInQueue(current: Song, queue: [Song]) -> Song? {
    guard !queue.isEmpty, let idx = queue.firstIndex(of: current) else { return nil }
    if idx + 1 < queue.count { return queue[idx + 1] }
    return nil
  }

  // MARK: - Pre-download

  private func predownload(song: Song, from remoteURL: URL) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let session = PredownloadSession(songID: song.id)
      self.predownloadSession = session
      session.onCompletion = { [weak self] in
        self?.predownloadSession = nil
        continuation.resume()
      }
      session.start(from: remoteURL)
    }
  }

  // MARK: - Reset

  func reset() {
    bpmTask?.cancel()
    bpmTask = nil
    predownloadSession?.cancel()
    predownloadSession = nil
    state = .idle
    onUpcomingSongDetermined?(nil)
  }
}

// MARK: - Pre-download helper

/// Lightweight download that streams to the audio cache.
/// Reuses the same cache directory as `AudioDownloadSession`.
private final class PredownloadSession: NSObject, URLSessionDataDelegate {
  private let songID: String
  private let partialURL: URL
  private let finalURL: URL
  private var fileHandle: FileHandle?
  private var task: URLSessionDataTask?
  private var session: URLSession?
  var onCompletion: (() -> Void)?

  init(songID: String) {
    self.songID = songID
    self.finalURL = AudioPlayerManager.audioCacheDir.appendingPathComponent("\(songID).mp3")
    self.partialURL = AudioPlayerManager.audioCacheDir.appendingPathComponent(
      "\(songID).mp3.partial")
    super.init()
  }

  func start(from remoteURL: URL) {
    // Don't re-download if already cached.
    if FileManager.default.fileExists(atPath: finalURL.path) {
      onCompletion?()
      return
    }
    try? FileManager.default.removeItem(at: partialURL)
    FileManager.default.createFile(atPath: partialURL.path, contents: nil)
    fileHandle = try? FileHandle(forWritingTo: partialURL)
    session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    task = session?.dataTask(with: remoteURL)
    task?.resume()
  }

  func cancel() {
    task?.cancel()
    session?.invalidateAndCancel()
    fileHandle?.closeFile()
    try? FileManager.default.removeItem(at: partialURL)
  }

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    fileHandle?.write(data)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    fileHandle?.closeFile()
    fileHandle = nil
    session.invalidateAndCancel()
    if error == nil,
      let http = task.response as? HTTPURLResponse, (200...299).contains(http.statusCode)
    {
      try? FileManager.default.removeItem(at: finalURL)
      try? FileManager.default.moveItem(at: partialURL, to: finalURL)
    } else {
      try? FileManager.default.removeItem(at: partialURL)
    }
    DispatchQueue.main.async { [weak self] in self?.onCompletion?() }
  }
}
