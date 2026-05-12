import AVFoundation
import Combine
import CoreML
import Foundation
import Spleeter

enum DeviceCapability {
  static var supportsKaraoke: Bool { VocalSeparator.shared.isAvailable }
}

enum VocalSeparatorError: Error {
  case unavailable
  case cancelled
  case modelMissing
  case trimFailed
  case readFailed
}

/// Holds URLs for all 4 cached stems of a song plus the timeline offset.
struct CachedStems {
  let vocals: URL
  let drums: URL
  let bass: URL
  let other: URL
  let startOffset: TimeInterval
}

/// Accumulated in-memory stem float arrays from streaming separation.
struct StreamingStems: @unchecked Sendable {
  var vocals: [Float]
  var drums: [Float]
  var bass: [Float]
  var other: [Float]
  let sampleRate: Double
  let startOffset: TimeInterval

  mutating func append(_ chunk: Stems4<[Float]>) {
    vocals.append(contentsOf: chunk.vocals)
    drums.append(contentsOf: chunk.drums)
    bass.append(contentsOf: chunk.bass)
    other.append(contentsOf: chunk.other)
  }
}

@MainActor
final class VocalSeparator: ObservableObject {
  static let shared = VocalSeparator()

  @Published private(set) var processingSongID: String?
  @Published private(set) var progressFraction: Float = 0

  let isAvailable: Bool
  private let modelURL: URL?
  private var activeTask: Task<URL, Error>?

  private static var stemsCacheDir: URL {
    let dir = AudioPlayerManager.audioCacheDir
      .appendingPathComponent("Stems", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  // Also keep old Instrumental dir path for migration / cleanup
  private static var legacyInstrumentalCacheDir: URL {
    AudioPlayerManager.audioCacheDir
      .appendingPathComponent("Instrumental", isDirectory: true)
  }

  private init() {
    let url = Bundle.main.url(forResource: "Spleeter4Model", withExtension: "mlmodelc")
    self.modelURL = url
    if #available(iOS 18.0, *) {
      self.isAvailable = (url != nil)
    } else {
      self.isAvailable = false
    }
    // Clean up legacy 2-stem cache
    try? FileManager.default.removeItem(at: Self.legacyInstrumentalCacheDir)
  }

  // MARK: - Per-stem cached URLs

  private func validCachedURL(_ url: URL) -> URL? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    // A valid WAV must be at least 44 bytes (header). Reject empty/truncated files.
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attrs[.size] as? UInt64, size > 44
    else { return nil }
    return url
  }

  func cachedVocalsURL(forSongID songID: String) -> URL? {
    validCachedURL(Self.stemsCacheDir.appendingPathComponent("\(songID).vocals.wav"))
  }

  func cachedDrumsURL(forSongID songID: String) -> URL? {
    validCachedURL(Self.stemsCacheDir.appendingPathComponent("\(songID).drums.wav"))
  }

  func cachedBassURL(forSongID songID: String) -> URL? {
    validCachedURL(Self.stemsCacheDir.appendingPathComponent("\(songID).bass.wav"))
  }

  func cachedOtherURL(forSongID songID: String) -> URL? {
    validCachedURL(Self.stemsCacheDir.appendingPathComponent("\(songID).other.wav"))
  }

  /// Returns all 4 cached stems plus the original-song time at which the stems begin.
  /// `startOffset = 0` means the stems cover the entire song.
  func cachedStems(forSongID songID: String) -> CachedStems? {
    guard let v = cachedVocalsURL(forSongID: songID),
      let d = cachedDrumsURL(forSongID: songID),
      let b = cachedBassURL(forSongID: songID),
      let o = cachedOtherURL(forSongID: songID)
    else { return nil }
    let offset = cachedStartOffset(forSongID: songID)
    return CachedStems(vocals: v, drums: d, bass: b, other: o, startOffset: offset)
  }

  func cachedStartOffset(forSongID songID: String) -> TimeInterval {
    let offsetURL = Self.stemsCacheDir.appendingPathComponent("\(songID).offset")
    guard let data = try? Data(contentsOf: offsetURL),
      let str = String(data: data, encoding: .utf8),
      let val = Double(str.trimmingCharacters(in: .whitespacesAndNewlines))
    else { return 0 }
    return val
  }

  /// Run Spleeter 4-stem separation on `sourceURL`. When `startTime > 0` the
  /// source is trimmed first so only the tail (startTime…end) is processed,
  /// cutting work in half if the user enables AI midway through a song.
  func separate(
    forSongID songID: String, sourceURL: URL, startTime: TimeInterval = 0
  ) async throws -> CachedStems {
    if let cached = cachedStems(forSongID: songID) { return cached }
    guard isAvailable, let modelURL else { throw VocalSeparatorError.unavailable }
    if processingSongID == songID, let active = activeTask {
      _ = try await active.value
      if let cached = cachedStems(forSongID: songID) { return cached }
      throw VocalSeparatorError.unavailable
    }
    if let old = activeTask {
      old.cancel()
      activeTask = nil
      processingSongID = nil
      progressFraction = 0
    }
    try Task.checkCancellation()
    guard #available(iOS 18.0, *) else { throw VocalSeparatorError.unavailable }
    processingSongID = songID
    let vocalsURL = Self.stemsCacheDir.appendingPathComponent("\(songID).vocals.wav")
    let drumsURL = Self.stemsCacheDir.appendingPathComponent("\(songID).drums.wav")
    let bassURL = Self.stemsCacheDir.appendingPathComponent("\(songID).bass.wav")
    let otherURL = Self.stemsCacheDir.appendingPathComponent("\(songID).other.wav")
    let offsetURL = Self.stemsCacheDir.appendingPathComponent("\(songID).offset")
    let modelRef = modelURL
    let normalizedStart = max(0, startTime)
    let task = Task<URL, Error>.detached {
      do {
        let trimmedSource: URL
        let trimmedTemp: URL?
        if normalizedStart > 1.0 {
          let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(songID).aitrim.m4a")
          try await Self.trim(source: sourceURL, from: normalizedStart, to: tmp)
          trimmedSource = tmp
          trimmedTemp = tmp
        } else {
          trimmedSource = sourceURL
          trimmedTemp = nil
        }
        try await Self.runSeparation4(
          modelURL: modelRef,
          songID: songID,
          sourceURL: trimmedSource,
          vocalsOutputURL: vocalsURL,
          drumsOutputURL: drumsURL,
          bassOutputURL: bassURL,
          otherOutputURL: otherURL
        ) { fraction in
          await VocalSeparator.shared.updateProgress(songID: songID, fraction: fraction)
        }
        if let trimmedTemp { try? FileManager.default.removeItem(at: trimmedTemp) }
        // Persist (or clear) the start-offset sidecar so playback can align timelines.
        try? FileManager.default.removeItem(at: offsetURL)
        if normalizedStart > 1.0 {
          try? "\(normalizedStart)".data(using: .utf8)?.write(to: offsetURL)
        }
        await VocalSeparator.shared.finishJob(songID: songID)
        return vocalsURL
      } catch {
        await VocalSeparator.shared.finishJob(songID: songID)
        throw error
      }
    }
    activeTask = task
    _ = try await task.value
    guard let stems = cachedStems(forSongID: songID) else {
      throw VocalSeparatorError.unavailable
    }
    return stems
  }

  func cancel() {
    let old = activeTask
    activeTask = nil
    processingSongID = nil
    progressFraction = 0
    old?.cancel()
  }

  func clearCache() {
    try? FileManager.default.removeItem(at: Self.stemsCacheDir)
    try? FileManager.default.removeItem(at: Self.legacyInstrumentalCacheDir)
  }

  private func updateProgress(songID: String, fraction: Float) {
    if processingSongID == songID { progressFraction = fraction }
  }

  fileprivate func finishJob(songID: String) {
    if processingSongID == songID {
      processingSongID = nil
      progressFraction = 0
      activeTask = nil
    }
  }

  private static func trim(source: URL, from startSeconds: TimeInterval, to output: URL) async throws {
    try? FileManager.default.removeItem(at: output)
    let asset = AVURLAsset(url: source)
    guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
    else { throw VocalSeparatorError.trimFailed }
    let start = CMTime(seconds: startSeconds, preferredTimescale: 600)
    let duration: CMTime
    if #available(iOS 16.0, *) {
      duration = try await asset.load(.duration)
    } else {
      duration = asset.duration
    }
    export.timeRange = CMTimeRange(start: start, end: duration)
    export.outputURL = output
    export.outputFileType = .m4a
    if #available(iOS 18.0, *) {
      try await export.export(to: output, as: .m4a)
    } else {
      await export.export()
      guard export.status == .completed else {
        throw export.error ?? VocalSeparatorError.trimFailed
      }
    }
  }

  @available(iOS 18.0, *)
  private static func runSeparation4(
    modelURL: URL,
    songID: String,
    sourceURL: URL,
    vocalsOutputURL: URL,
    drumsOutputURL: URL,
    bassOutputURL: URL,
    otherOutputURL: URL,
    onProgress: @Sendable @escaping (Float) async -> Void
  ) async throws {
    let separator = try AudioSeparator4(modelURL: modelURL)
    let tmpDir = FileManager.default.temporaryDirectory
    let tmpVocals = tmpDir.appendingPathComponent("\(songID).vocals.wav")
    let tmpDrums = tmpDir.appendingPathComponent("\(songID).drums.wav")
    let tmpBass = tmpDir.appendingPathComponent("\(songID).bass.wav")
    let tmpOther = tmpDir.appendingPathComponent("\(songID).other.wav")
    try? FileManager.default.removeItem(at: tmpVocals)
    try? FileManager.default.removeItem(at: tmpDrums)
    try? FileManager.default.removeItem(at: tmpBass)
    try? FileManager.default.removeItem(at: tmpOther)
    let stems = Stems4(vocals: tmpVocals, drums: tmpDrums, bass: tmpBass, other: tmpOther)
    do {
      for try await prog in separator.separate(from: sourceURL, to: stems) {
        try Task.checkCancellation()
        await onProgress(prog.fraction)
      }
    } catch is CancellationError {
      Self.cleanupTmpFiles([tmpVocals, tmpDrums, tmpBass, tmpOther])
      throw VocalSeparatorError.cancelled
    } catch {
      Self.cleanupTmpFiles([tmpVocals, tmpDrums, tmpBass, tmpOther])
      throw error
    }
    // Move each stem from tmp to the cache directory
    let moves: [(URL, URL)] = [
      (tmpVocals, vocalsOutputURL),
      (tmpDrums, drumsOutputURL),
      (tmpBass, bassOutputURL),
      (tmpOther, otherOutputURL),
    ]
    for (src, dst) in moves {
      try? FileManager.default.removeItem(at: dst)
      do {
        try FileManager.default.moveItem(at: src, to: dst)
      } catch {
        try? FileManager.default.removeItem(at: src)
      }
    }
  }

  /// Streaming separation: reads source audio into memory and processes chunk-by-chunk,
  /// calling `onChunk` each time a new ~5s chunk is ready so the caller can apply AI
  /// effects progressively without waiting for the entire song.
  @available(iOS 18.0, *)
  func separateStreaming(
    forSongID songID: String, sourceURL: URL, startTime: TimeInterval = 0,
    onChunk: @escaping @Sendable (StreamingStems, Float) async -> Void
  ) async throws -> CachedStems {
    guard isAvailable, let modelURL else { throw VocalSeparatorError.unavailable }
    if let old = activeTask {
      old.cancel()
      activeTask = nil
      processingSongID = nil
      progressFraction = 0
    }
    try Task.checkCancellation()
    processingSongID = songID

    let normalizedStart = max(0, startTime)
    let modelRef = modelURL
    let vocalsURL = Self.stemsCacheDir.appendingPathComponent("\(songID).vocals.wav")
    let drumsURL = Self.stemsCacheDir.appendingPathComponent("\(songID).drums.wav")
    let bassURL = Self.stemsCacheDir.appendingPathComponent("\(songID).bass.wav")
    let otherURL = Self.stemsCacheDir.appendingPathComponent("\(songID).other.wav")
    let offsetURL = Self.stemsCacheDir.appendingPathComponent("\(songID).offset")

    let task = Task<URL, Error>.detached {
      do {
        let trimmedSource: URL
        let trimmedTemp: URL?
        if normalizedStart > 1.0 {
          let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(songID).aitrim.m4a")
          try await VocalSeparator.trim(source: sourceURL, from: normalizedStart, to: tmp)
          trimmedSource = tmp
          trimmedTemp = tmp
        } else {
          trimmedSource = sourceURL
          trimmedTemp = nil
        }

        let spleeterFile = try Spleeter.AudioFile(forReading: trimmedSource)
        let sampleRate = spleeterFile.sampleRate
        let waveform = try spleeterFile.readStereoSamples()

        let separator = try AudioSeparator4(modelURL: modelRef)
        var accumulated = StreamingStems(
          vocals: [], drums: [], bass: [], other: [],
          sampleRate: sampleRate, startOffset: normalizedStart)

        for try await (chunkStems, prog) in separator.separate(waveform) {
          try Task.checkCancellation()
          if let chunkStems {
            accumulated.append(chunkStems)
            await onChunk(accumulated, prog.fraction)
          }
          await VocalSeparator.shared.updateProgress(songID: songID, fraction: prog.fraction)
        }

        // Write final stems to cache as WAV files
        try Self.writeMonoWAV(samples: accumulated.vocals, sampleRate: sampleRate, to: vocalsURL)
        try Self.writeMonoWAV(samples: accumulated.drums, sampleRate: sampleRate, to: drumsURL)
        try Self.writeMonoWAV(samples: accumulated.bass, sampleRate: sampleRate, to: bassURL)
        try Self.writeMonoWAV(samples: accumulated.other, sampleRate: sampleRate, to: otherURL)

        try? FileManager.default.removeItem(at: offsetURL)
        if normalizedStart > 1.0 {
          try? "\(normalizedStart)".data(using: .utf8)?.write(to: offsetURL)
        }
        if let trimmedTemp { try? FileManager.default.removeItem(at: trimmedTemp) }
        await VocalSeparator.shared.finishJob(songID: songID)
        return vocalsURL
      } catch {
        await VocalSeparator.shared.finishJob(songID: songID)
        throw error
      }
    }
    activeTask = task
    _ = try await task.value
    guard let stems = cachedStems(forSongID: songID) else {
      throw VocalSeparatorError.unavailable
    }
    return stems
  }

  nonisolated private static func writeMonoWAV(samples: [Float], sampleRate: Double, to url: URL) throws {
    try? FileManager.default.removeItem(at: url)
    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
    else { return }
    let frameCount = AVAudioFrameCount(samples.count)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
    buffer.frameLength = frameCount
    if let dst = buffer.floatChannelData?[0] {
      samples.withUnsafeBufferPointer { src in
        dst.initialize(from: src.baseAddress!, count: samples.count)
      }
    }
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
  }

  private static func cleanupTmpFiles(_ urls: [URL]) {
    for url in urls {
      try? FileManager.default.removeItem(at: url)
    }
  }
}
