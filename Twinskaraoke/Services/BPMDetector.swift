import Accelerate
import AVFoundation
import Foundation

/// On-device BPM detection using Accelerate/vDSP.
///
/// Analyzes ~30 seconds from the middle of a track (skipping intro/outro),
/// computes an onset-strength envelope, autocorrelates it, and picks the
/// strongest peak in the 60–200 BPM range.
enum BPMDetector {

  // MARK: - Public API

  /// Detect the BPM of the audio file at `url`.
  /// Runs on a background thread (~0.3–0.8 s for a typical MP3).
  /// Returns `nil` when the file can't be decoded or confidence is too low.
  static func detect(url: URL) async -> Double? {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .utility).async {
        let result = detectSync(url: url)
        continuation.resume(returning: result)
      }
    }
  }

  // MARK: - Internal

  /// Analysis sample rate — we downsample to mono 22 050 Hz for efficiency.
  private static let analysisSR: Double = 22050

  /// Hop size in samples for the onset envelope (~11.6 ms per frame).
  private static let hopSize: Int = 256

  /// Window size in samples for RMS energy frames.
  private static let windowSize: Int = 1024

  /// Duration (seconds) of audio to analyze.
  private static let analysisSeconds: Double = 30

  /// Minimum BPM we'll consider.
  private static let minBPM: Double = 60

  /// Maximum BPM we'll consider.
  private static let maxBPM: Double = 200

  /// The peak must be at least this factor above the median autocorrelation
  /// to be accepted as a confident detection.
  private static let confidenceThreshold: Float = 1.4

  // MARK: - Synchronous pipeline

  private static func detectSync(url: URL) -> Double? {
    guard let samples = loadMonoSamples(url: url) else { return nil }
    guard samples.count > windowSize else { return nil }

    let envelope = onsetEnvelope(samples)
    guard envelope.count > 2 else { return nil }

    return bpmFromAutocorrelation(envelope)
  }

  // MARK: - Step 1: Load & downsample to mono

  private static func loadMonoSamples(url: URL) -> [Float]? {
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .audio).first else { return nil }
    guard let reader = try? AVAssetReader(asset: asset) else { return nil }

    let outputSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: analysisSR,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
    reader.add(output)

    // Seek to the middle of the track, skipping intro/outro.
    let totalSeconds = asset.duration.seconds
    guard totalSeconds > 5 else {
      // Very short file — analyze the whole thing.
      return readAllSamples(reader: reader, output: output, maxFrames: nil)
    }
    let analysisLen = min(analysisSeconds, totalSeconds * 0.6)
    let startTime = max(0, (totalSeconds - analysisLen) / 2)
    let endTime = startTime + analysisLen
    let timeRange = CMTimeRange(
      start: CMTime(seconds: startTime, preferredTimescale: 44100),
      end: CMTime(seconds: endTime, preferredTimescale: 44100)
    )
    reader.timeRange = timeRange

    let maxFrames = Int(analysisLen * analysisSR) + 8192
    return readAllSamples(reader: reader, output: output, maxFrames: maxFrames)
  }

  private static func readAllSamples(
    reader: AVAssetReader, output: AVAssetReaderTrackOutput, maxFrames: Int?
  ) -> [Float]? {
    guard reader.startReading() else { return nil }
    var all = [Float]()
    let cap = maxFrames ?? Int.max
    while reader.status == .reading {
      guard let sb = output.copyNextSampleBuffer(),
        let bb = CMSampleBufferGetDataBuffer(sb)
      else { break }
      let sampleCount = CMSampleBufferGetNumSamples(sb)
      var length = 0
      var dataPtr: UnsafeMutablePointer<Int8>?
      guard
        CMBlockBufferGetDataPointer(
          bb, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length,
          dataPointerOut: &dataPtr) == noErr,
        let dataPtr
      else { continue }
      let floatPtr = UnsafeRawPointer(dataPtr).bindMemory(to: Float.self, capacity: sampleCount)
      let toAppend = min(sampleCount, cap - all.count)
      guard toAppend > 0 else { break }
      all.append(contentsOf: UnsafeBufferPointer(start: floatPtr, count: toAppend))
      if all.count >= cap { break }
    }
    return all.isEmpty ? nil : all
  }

  // MARK: - Step 2: Onset-strength envelope

  /// Compute frame-by-frame RMS energy, then first-order difference (half-wave rectified)
  /// to get an onset-strength signal.
  private static func onsetEnvelope(_ samples: [Float]) -> [Float] {
    let frameCount = (samples.count - windowSize) / hopSize + 1
    guard frameCount > 1 else { return [] }

    // RMS energy per frame
    var rms = [Float](repeating: 0, count: frameCount)
    for i in 0..<frameCount {
      let offset = i * hopSize
      let end = min(offset + windowSize, samples.count)
      let count = end - offset
      guard count > 0 else { continue }
      var val: Float = 0
      samples.withUnsafeBufferPointer { buf in
        vDSP_rmsqv(buf.baseAddress! + offset, 1, &val, vDSP_Length(count))
      }
      rms[i] = val
    }

    // First-order difference, half-wave rectified → onset strength
    var onset = [Float](repeating: 0, count: frameCount - 1)
    for i in 0..<onset.count {
      let diff = rms[i + 1] - rms[i]
      onset[i] = max(0, diff)
    }
    return onset
  }

  // MARK: - Step 3: Autocorrelation → BPM

  private static func bpmFromAutocorrelation(_ envelope: [Float]) -> Double? {
    let n = envelope.count
    // Onset envelope frame rate
    let onsetSR = analysisSR / Double(hopSize)

    // Lag range corresponding to BPM range
    let minLag = Int(onsetSR * 60.0 / maxBPM)
    let maxLag = Int(onsetSR * 60.0 / minBPM)
    guard minLag >= 1, maxLag < n, minLag < maxLag else { return nil }

    // Compute normalized autocorrelation for the lag range
    let lagCount = maxLag - minLag + 1
    var acf = [Float](repeating: 0, count: lagCount)

    envelope.withUnsafeBufferPointer { buf in
      for i in 0..<lagCount {
        let lag = minLag + i
        let overlapLen = n - lag
        guard overlapLen > 0 else { continue }
        var dot: Float = 0
        vDSP_dotpr(
          buf.baseAddress!, 1,
          buf.baseAddress! + lag, 1,
          &dot,
          vDSP_Length(overlapLen)
        )
        acf[i] = dot / Float(overlapLen)
      }
    }

    // Find the peak
    var peakVal: Float = 0
    var peakIdx: vDSP_Length = 0
    vDSP_maxvi(acf, 1, &peakVal, &peakIdx, vDSP_Length(lagCount))

    // Confidence check: peak should be significantly above the median
    var sorted = acf
    vDSP_vsort(&sorted, vDSP_Length(lagCount), 1)
    let medianVal = sorted[lagCount / 2]
    guard medianVal > 0, peakVal / medianVal >= confidenceThreshold else { return nil }

    let bestLag = minLag + Int(peakIdx)
    guard bestLag > 0 else { return nil }
    let bpm = onsetSR * 60.0 / Double(bestLag)

    // Normalize to the 60–200 range (handle octave errors)
    return normalizedBPM(bpm)
  }

  /// If the detected BPM is outside 60–200, try halving or doubling to bring
  /// it into range (handles common octave-error from autocorrelation).
  private static func normalizedBPM(_ raw: Double) -> Double? {
    if raw >= minBPM && raw <= maxBPM { return raw }
    let doubled = raw * 2
    if doubled >= minBPM && doubled <= maxBPM { return doubled }
    let halved = raw / 2
    if halved >= minBPM && halved <= maxBPM { return halved }
    return nil
  }
}
