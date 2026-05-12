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

struct CachedStems {
  let vocals: URL
  let drums: URL
  let bass: URL
  let other: URL
  let startOffset: TimeInterval
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
    try? FileManager.default.removeItem(at: Self.legacyInstrumentalCacheDir)
  }

  private func validCachedURL(_ url: URL) -> URL? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
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

  private static func cleanupTmpFiles(_ urls: [URL]) {
    for url in urls {
      try? FileManager.default.removeItem(at: url)
    }
  }
}
