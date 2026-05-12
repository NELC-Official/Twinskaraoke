# iOS Karaoke App: Audio Pipeline Architecture Analysis

## Executive Summary

This is a sophisticated, multi-layered audio processing pipeline built with **AudioKit** at the foundation, a custom **vDSP-based DSP layer** for real-time effects, an **AI-powered vocal separation system** using Spleeter (iOS 18+), and multiple audio effects modes that are mutually exclusive.

---

## 1. BACKGROUND PLAYBACK & NEXT TRACK BEHAVIOR

### Entry Point: `play()` Method
**Location:** `AudioPlayerManager.swift:385-439`

The `play()` method orchestrates the entire playback flow:

```swift
func play(song: Song, context: [Song] = []) {
  // 1. Stop any active radio playback
  if isRadioMode { RadioController.shared.stop() }
  stopRadioPlayer()
  isRadioMode = false
  
  // 2. Report play count (telemetry)
  reportPlayCount(for: song.id)
  
  // 3. Update currentSong (published property triggers UI updates)
  if currentSong?.id != song.id {
    progress = 0
    withAnimation(.easeInOut(duration: 0.32)) {
      currentSong = song
    }
  }
  
  // 4. Set queue context
  if !context.isEmpty {
    queue = context
    if isShuffled {
      originalQueue = context
      var rest = queue.filter { $0.id != song.id }
      rest.shuffle()
      queue = [song] + rest
    } else {
      originalQueue = []
    }
  }
  
  // 5. Locate or download audio file
  let downloadedURL = DownloadManager.shared.localURL(for: song.id)
  let cacheURL = AudioPlayerManager.audioCacheDir.appendingPathComponent("\(song.id).mp3")
  
  if FileManager.default.fileExists(atPath: downloadedURL.path) {
    startPlayingFile(downloadedURL)
    applyMLSeparationIfNeeded()
    return
  }
  if FileManager.default.fileExists(atPath: cacheURL.path) {
    startPlayingFile(cacheURL)
    applyMLSeparationIfNeeded()
    return
  }
  
  // 6. Download from remote URL if not cached
  isBuffering = true
  let session = AudioDownloadSession(songID: songID)
  session.onCompletion = { [weak self] url in
    // Completion handler calls startPlayingFile() + applyMLSeparationIfNeeded()
  }
  session.start(from: remoteURL)
}
```

### Track Ending & Queue Navigation
**Location:** `AudioPlayerManager.swift:303-306` (init) and `509-528` (playNextOrRandom)

When a track ends in the AudioKit player:

```swift
audioKit.onPlaybackEnded = { [weak self] in
  guard let self, !self.isRadioMode else { return }
  self.playNextOrRandom()  // ← Entry point for next track logic
}
```

The `playNextOrRandom()` method handles three scenarios:

```swift
func playNextOrRandom() {
  if isRadioMode { return }
  
  // Scenario 1: Repeat mode = one
  if repeatMode == .one, let current = currentSong {
    play(song: current)
    return
  }
  
  // Scenario 2: Next track in queue exists
  if let current = currentSong, !queue.isEmpty, 
     let idx = queue.firstIndex(of: current), idx + 1 < queue.count {
    play(song: queue[idx + 1])
  }
  // Scenario 3: Repeat all, loop to first
  else if repeatMode == .all, let first = queue.first {
    play(song: first)
  }
  // Scenario 4: Autoplay enabled, fetch random trending
  else if autoplayEnabled {
    fetchRandomTrending()
  }
  // Scenario 5: Stop playback
  else {
    isPlaying = false
    audioKit.pause()
    updateNowPlayingInfo(reloadArtwork: false)
  }
}
```

### Key Properties for Background Playback

| Property | Type | Persisted | Purpose |
|----------|------|-----------|---------|
| `currentSong` | `@Published Song?` | ❌ | Current playing track |
| `queue` | `@Published [Song]` | ❌ | Up-next queue |
| `repeatMode` | `RepeatMode` (enum) | ❌ | off/all/one |
| `autoplayEnabled` | `@Published Bool` | ❌ | Auto-play random trending when queue ends |
| `isRadioMode` | `@Published Bool` | ❌ | Radio stream vs local file mode |

---

## 2. KARAOKE MODE, BASS ENHANCE, AND VOICE ENHANCE PROPERTIES

### Audio Effects Modes (Mutually Exclusive)

The app implements **three mutually exclusive audio effects modes**, controlled via sophisticated logic to prevent simultaneous activation:

#### A. Karaoke Mode (Vocal Removal)

**@Published Properties:**
```swift
@Published var karaokeMode: Bool = false {
  didSet {
    KaraokeAudioProcessor.vocalRemovalLevel = karaokeMode ? karaokeLevel : .off
    if _suppressDSPApply { return }
    
    // Deactivate competing modes
    if karaokeMode {
      if vocalEnhanceMode { _suppressDSPApply = true; vocalEnhanceMode = false; _suppressDSPApply = false }
      if bassEnhanceMode { _suppressDSPApply = true; bassEnhanceMode = false; _suppressDSPApply = false }
      if eqEnabled { _suppressDSPApply = true; eqEnabled = false; _suppressDSPApply = false }
    }
    applyDSPSettings()
    applyMLSeparationIfNeeded()
  }
}

@Published var karaokeLevel: VocalRemovalLevel = .strong {
  didSet {
    if karaokeMode {
      KaraokeAudioProcessor.vocalRemovalLevel = karaokeLevel
      applyDSPSettings()
    }
  }
}

@Published var karaokeStrength: Float = 0.85 {  // 0.0 - 1.0 slider
  didSet {
    let newLevel: VocalRemovalLevel
    if karaokeStrength < 0.125 { newLevel = .off }
    else if karaokeStrength < 0.375 { newLevel = .light }
    else if karaokeStrength < 0.625 { newLevel = .medium }
    else if karaokeStrength < 0.875 { newLevel = .strong }
    else { newLevel = .maximum }
    if newLevel != karaokeLevel { karaokeLevel = newLevel }
  }
}
```

**VocalRemovalLevel Enum:**
```swift
enum VocalRemovalLevel: Int {
  case off = 0          // centerAttenuation: 0.0
  case light = 1        // centerAttenuation: 0.7
  case medium = 2       // centerAttenuation: 0.9
  case strong = 3       // centerAttenuation: 1.0
  case maximum = 4      // centerAttenuation: 1.0 + 1.25x boost
}
```

**ML-based Vocal Removal (iOS 18+):**
```swift
@Published var mlVocalRemoval: Bool = UserDefaults.standard.bool(forKey: "nk.mlVocalRemoval") {
  didSet {
    UserDefaults.standard.set(mlVocalRemoval, forKey: "nk.mlVocalRemoval")
    applyMLSeparationIfNeeded()
  }
}

@Published var aiVocalStrength: Float = AudioPlayerManager.loadAIVocalStrength() {
  didSet {
    let clamped = min(1, max(0, aiVocalStrength))
    if clamped != aiVocalStrength { aiVocalStrength = clamped; return }
    UserDefaults.standard.set(Double(aiVocalStrength), forKey: "nk.aiVocalStrength")
    audioKit.setAIVocalStrength(aiVocalStrength)
  }
}
```

#### B. Bass Enhance Mode

```swift
@Published var bassEnhanceMode: Bool = false {
  didSet {
    guard !_suppressDSPApply else { return }
    if bassEnhanceMode {
      if karaokeMode { _suppressDSPApply = true; karaokeMode = false; _suppressDSPApply = false }
      if vocalEnhanceMode { _suppressDSPApply = true; vocalEnhanceMode = false; _suppressDSPApply = false }
      if eqEnabled { _suppressDSPApply = true; eqEnabled = false; _suppressDSPApply = false }
    }
    applyDSPSettings()
  }
}

@Published var bassEnhanceStrength: Float = 0.5 {  // 0.0 - 1.0 slider
  didSet { applyDSPSettings() }
}
```

#### C. Vocal Enhance Mode

```swift
@Published var vocalEnhanceMode: Bool = false {
  didSet {
    guard !_suppressDSPApply else { return }
    if vocalEnhanceMode {
      if karaokeMode { _suppressDSPApply = true; karaokeMode = false; _suppressDSPApply = false }
      if bassEnhanceMode { _suppressDSPApply = true; bassEnhanceMode = false; _suppressDSPApply = false }
      if eqEnabled { _suppressDSPApply = true; eqEnabled = false; _suppressDSPApply = false }
    }
    applyDSPSettings()
  }
}

@Published var vocalEnhanceStrength: Float = 0.5 {  // 0.0 - 1.0 slider
  didSet { applyDSPSettings() }
}
```

#### D. EQ (10-band parametric)

```swift
@Published var eqEnabled: Bool = false {
  didSet {
    audioKit.setEQEnabled(eqEnabled)
    guard !_suppressDSPApply else { return }
    if eqEnabled {
      if karaokeMode { _suppressDSPApply = true; karaokeMode = false; _suppressDSPApply = false }
      if bassEnhanceMode { _suppressDSPApply = true; bassEnhanceMode = false; _suppressDSPApply = false }
      if vocalEnhanceMode { _suppressDSPApply = true; vocalEnhanceMode = false; _suppressDSPApply = false }
    }
  }
}

@Published var eqPreset: EQPreset = .flat {
  didSet {
    guard eqPreset != .custom else { return }
    eqPresetIsApplying = true
    eqGainsDB = eqPreset.gains  // Apply preset gains
    eqPresetIsApplying = false
  }
}

@Published var eqGainsDB: [Float] = Array(repeating: 0, count: 10) {
  didSet {
    audioKit.setEQGains(eqGainsDB)
    if !eqPresetIsApplying && eqPreset != .custom && eqGainsDB != eqPreset.gains {
      eqPreset = .custom
    }
  }
}
```

**EQPreset Enum (11 presets + custom):**
```swift
enum EQPreset: String {
  case flat, bass, treble, vocal, rock, pop, jazz, electronic, classical, hiphop, loudness, custom
  
  var gains: [Float] {  // 10 bands (31.5Hz - 16kHz)
    switch self {
    case .flat:       return [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0]
    case .bass:       return [10,  8,  5,  2,  0,  0,  0,  0,  0,  0]
    case .treble:     return [ 0,  0,  0,  0,  0,  2,  4,  6,  8, 10]
    case .vocal:      return [-2, -1,  0,  3,  6,  6,  4,  2,  0, -1]
    case .rock:       return [ 5,  4,  2,  0, -2, -1,  2,  4,  5,  6]
    case .pop:        return [-1,  2,  4,  5,  3,  0, -1,  0,  2,  3]
    // ... (7 more presets)
    }
  }
}
```

### Toggling Logic (Suppression Mechanism)

The `_suppressDSPApply` flag prevents feedback loops when deactivating competing modes:

```swift
private var _suppressDSPApply = false
```

When a mode is enabled, competing modes are disabled with suppression:
1. Set `_suppressDSPApply = true`
2. Toggle competing mode = false (no didSet cascade)
3. Set `_suppressDSPApply = false`
4. Call `applyDSPSettings()`

This ensures only one mode is active at a time.

---

## 3. CROSSFADE & AUTO-MIX TRANSITIONS

### Crossfade Properties (Unused - No Implementation)

```swift
@Published var crossfadeEnabled: Bool =
  (UserDefaults.standard.object(forKey: "nk.crossfadeEnabled") as? Bool ?? false)
{
  didSet {
    UserDefaults.standard.set(crossfadeEnabled, forKey: "nk.crossfadeEnabled")
    if crossfadeEnabled && autoMixEnabled { autoMixEnabled = false }
  }
}

@Published var crossfadeSeconds: Double = AudioPlayerManager.loadCrossfadeSeconds() {
  didSet {
    let clamped = min(15, max(1, crossfadeSeconds))
    if clamped != crossfadeSeconds { crossfadeSeconds = clamped; return }
    UserDefaults.standard.set(crossfadeSeconds, forKey: "nk.crossfadeSeconds")
  }
}
```

**Status:** ⚠️ **These properties are defined but NO implementation of actual crossfade logic exists.**

### Auto-Mix Properties (Unused - No Implementation)

```swift
@Published var autoMixEnabled: Bool =
  (UserDefaults.standard.object(forKey: "nk.autoMixEnabled") as? Bool ?? true)
{
  didSet {
    UserDefaults.standard.set(autoMixEnabled, forKey: "nk.autoMixEnabled")
    if autoMixEnabled && crossfadeEnabled { crossfadeEnabled = false }
  }
}
```

**Status:** ⚠️ **Persists to UserDefaults but NO audio mixing implementation found.**

### Missing Implementation

- ❌ No `scheduleAutoMixIfNeeded()` method found
- ❌ No `beginCrossfade()` method found
- ❌ No `cancelAutoMix()` method found
- ❌ No upcoming track pre-loading
- ❌ No scheduled fade-in/fade-out
- ❌ No mix point scheduling

**Conclusion:** These are UI stubs (probably for Settings UI) but the actual crossfade/auto-mix audio DSP is not implemented.

---

## 4. HOW PLAY() METHOD WORKS & TRACK END BEHAVIOR

### Complete Play Flow

```
play(song, context) 
  ↓
[Check/stop radio mode]
  ↓
[Report play count telemetry]
  ↓
[Update currentSong @Published]
  ↓
[Set queue from context]
  ↓
[Handle shuffle if enabled]
  ↓
[Check file locations: downloaded → cached → remote]
  ↓
[If cached: startPlayingFile() → applyMLSeparationIfNeeded()]
  ↓
[If not cached: Download → onCompletion → startPlayingFile()]
```

### startPlayingFile()

```swift
private func startPlayingFile(_ url: URL) {
  currentPlaybackURL = url
  playingInstrumentalForSongID = nil
  NotificationCenter.default.post(name: MediaPlaybackCoordinator.audioWillPlay, object: nil)
  audioKit.play(url: url)
  isPlaying = true
  isBuffering = false
  updateNowPlayingInfo(reloadArtwork: true)
}
```

### Track End Event

1. AudioKit's internal `AVAudioPlayerNode` finishes playing
2. Completion handler fires: `audioKit.onPlaybackEnded`
3. Calls `playNextOrRandom()`
4. Determines next track based on repeat mode / autoplay
5. Calls `play(nextSong)` → cycle repeats

---

## 5. DSP-BASED VOICE REMOVAL ARCHITECTURE

### KaraokeAudioProcessor (vDSP-based, realtime)

**Location:** `KaraokeAudioProcessor.swift`

Module-level statics read by realtime audio thread (low-latency DSP):

```swift
enum KaraokeAudioProcessor {
  static var vocalRemovalLevel: VocalRemovalLevel = .off
  static var bassEnhanceStrength: Float = 0
  static var vocalEnhanceStrength: Float = 0
  static var suppressVocalRemoval: Bool = false
  static let bandCount = 10
  static let bandFrequencies: [Double] = [
    31.5, 63, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000
  ]
  
  static func prepare(sampleRate: Double, maxFrames: Int)
  static func reset()
  static func processInPlace(bufferList: UnsafeMutableAudioBufferListPointer, numFrames: Int)
}
```

### Voice Removal Algorithm (Biquad + Mid-Side Processing)

**How it works:**

1. **Mid-Side Decomposition:** Convert stereo L/R to Mid (L+R) and Side (L-R)
   ```
   Mid = (L + R) / 2          [Contains vocals, centered]
   Side = (L - R) / 2         [Contains stereo effects]
   ```

2. **Biquad Bandpass Filter:** Apply 6-section cascade filter to Mid channel
   - 3x Highpass @ 250 Hz (vocal low cutoff)
   - 3x Lowpass @ 6 kHz (vocal high cutoff)
   - Isolates vocal frequencies in Mid channel

3. **Center Attenuation:** Subtract filtered mid from original mid
   ```swift
   var negAtt: Float = -level.centerAttenuation  // 0.7, 0.9, 1.0
   vDSP_vsma(tmp, 1, &negAtt, mid, 1, mid, 1, n)  // mid -= att * filtered_mid
   ```

4. **Optional Boost (Maximum level only):**
   ```swift
   if level == .maximum {
     vDSP_vsmul(mid, 1, &boost, mid, 1, n)   // mid *= 1.25
     vDSP_vsmul(side, 1, &boost, side, 1, n) // side *= 1.25
   }
   ```

5. **Mid-Side Recombine:** Convert back to L/R
   ```
   L = Mid + Side
   R = Mid - Side
   ```

### Bass Enhance Algorithm

1. Mid-Side decomposition
2. Apply shaped gain curve: `shaped = strength * strength * (3 - 2 * strength)`
3. Decompose mid into:
   - Low bass (0-120 Hz) via 1-pole lowpass
   - Mid (120 Hz - 9 kHz)
   - Treble (9 kHz+) via 1-pole lowpass
4. Boost bass section: `bassBoost = 1.0 + shaped * 3.0`
5. Mix: `output = bass_boosted + mid + treble` with makeup gain
6. Soft-clip via `vvtanhf()` to prevent distortion

### Vocal Enhance Algorithm

1. Mid-Side decomposition
2. Apply shaped gain curve
3. Decompose mid into vocal range (250 Hz - 6 kHz):
   - Low (0-250 Hz)
   - Vocal (250-6000 Hz)
   - High (6000+ Hz)
4. Boost vocal range: `vocalBoost = 1.0 + shaped * 3.0`
5. Presence boost on highs: `presenceBoost = 1.0 + shaped * 1.2`
6. Attenuate stereo side information
7. Soft-clip to prevent distortion

### KaraokeDSPAudioUnit (Custom V3 Audio Unit)

**Location:** `KaraokeDSPAudioUnit.swift`

Custom AUAudioUnit that wraps vDSP processing in realtime render callback:

```swift
final class KaraokeDSPAudioUnit: AUAudioUnit {
  // Runs on realtime audio thread
  override var internalRenderBlock: AUInternalRenderBlock {
    return { actionFlags, timestamp, frameCount, _, outputData, _, pullInputBlock in
      guard let pull = pullInputBlock else { return kAudioUnitErr_NoConnection }
      
      // Pull input from previous node
      var inputFlags: AudioUnitRenderActionFlags = []
      let status = pull(&inputFlags, timestamp, frameCount, 0, outputData)
      if status != noErr { return status }
      
      // Apply vDSP processing in-place
      let abl = UnsafeMutableAudioBufferListPointer(outputData)
      KaraokeAudioProcessor.processInPlace(bufferList: abl, numFrames: Int(frameCount))
      
      return noErr
    }
  }
}
```

**Audio Graph Chain:**
```
MainPlayer ─┐
            ├→ Mixer ─→ KaraokeDSPUnit ─→ UserEQ ─→ Output
AuxPlayer ─┘
```

---

## 6. AI-BASED VOCAL SEPARATION (Spleeter, iOS 18+)

### VocalSeparator (ML-powered)

**Location:** `VocalSeparator.swift`

Uses Spleeter v2 CoreML model (bundled in app):

```swift
@MainActor
final class VocalSeparator: ObservableObject {
  static let shared = VocalSeparator()
  
  @Published private(set) var processingSongID: String?
  @Published private(set) var progressFraction: Float = 0
  
  let isAvailable: Bool  // iOS 18+ only
  private let modelURL: URL?
}
```

### Workflow: AI Vocal Separation

**When enabled:**
```swift
private func applyMLSeparationIfNeeded() {
  guard !isRadioMode, let song = currentSong else { return }
  
  let shouldUseML = karaokeMode && mlVocalRemoval && VocalSeparator.shared.isAvailable
  guard shouldUseML else {
    VocalSeparator.shared.cancel()
    revertFromInstrumentalIfActive()
    return
  }
  
  // Check cache first
  if let pair = VocalSeparator.shared.cachedAIPair(forSongID: song.id) {
    swapToAITrack(
      songID: song.id,
      instrumentalURL: pair.instrumental,
      vocalsURL: pair.vocals,
      startOffset: pair.startOffset
    )
    return
  }
  
  // Clean legacy cache (instrumental only, no vocals)
  if let staleInstrumental = VocalSeparator.shared.cachedInstrumentalURL(forSongID: song.id) {
    try? FileManager.default.removeItem(at: staleInstrumental)
  }
  
  // Start separation task (async)
  let trimStart = audioKit.currentTime
  instrumentalTask = Task { [weak self] in
    // Poll for audio file availability (up to 10 minutes)
    while Date() < deadline {
      if Task.isCancelled { return }
      
      let sourceURL = // Check downloaded / cached locations
      if let sourceURL {
        let url = try await VocalSeparator.shared.instrumental(
          forSongID: songID, sourceURL: sourceURL, startTime: trimStart
        )
        
        // Swap to AI track on main thread
        await MainActor.run { [weak self] in
          let vocals = VocalSeparator.shared.cachedVocalsURL(forSongID: songID)
          let offset = VocalSeparator.shared.cachedAIStartOffset(forSongID: songID)
          self?.swapToAITrack(
            songID: songID,
            instrumentalURL: url,
            vocalsURL: vocals,
            startOffset: offset
          )
        }
        return
      }
      try? await Task.sleep(nanoseconds: 2_000_000_000)  // Wait 2s, retry
    }
  }
}
```

### Spleeter Separation Process

```swift
@available(iOS 18.0, *)
private static func runSeparation(
  modelURL: URL, songID: String, sourceURL: URL,
  outputURL: URL, vocalsOutputURL: URL,
  onProgress: @Sendable @escaping (Float) async -> Void
) async throws -> URL {
  // 1. Instantiate Spleeter v2 model
  let separator = try AudioSeparator2(modelURL: modelURL)
  
  // 2. Define output stem locations
  let tmpVocals = tmpDir.appendingPathComponent("\(songID).vocals.wav")
  let tmpInstr = tmpDir.appendingPathComponent("\(songID).instr.wav")
  let stems = Stems2(vocals: tmpVocals, accompaniment: tmpInstr)
  
  // 3. Run separation (async generator, progress callbacks)
  for try await prog in separator.separate(from: sourceURL, to: stems) {
    try Task.checkCancellation()
    await onProgress(prog.fraction)  // Update UI progress bar
  }
  
  // 4. Move temporary files to cache
  try FileManager.default.moveItem(at: tmpInstr, to: outputURL)
  try FileManager.default.moveItem(at: tmpVocals, to: vocalsOutputURL)
  
  // 5. Persist start offset for timeline alignment
  if normalizedStart > 1.0 {
    try? "\(normalizedStart)".data(using: .utf8)?.write(to: offsetURL)
  }
  
  return outputURL
}
```

### Optional Trimming (If User Enables AI Mid-Song)

If karaoke mode is enabled after playback has started:

```swift
if normalizedStart > 1.0 {
  let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(songID).aitrim.m4a")
  try await Self.trim(source: sourceURL, from: normalizedStart, to: tmp)
  // Only separate the tail of the song, skip already-heard audio
}
```

### Swapping to AI Track

```swift
private func swapToAITrack(
  songID: String, instrumentalURL: URL, vocalsURL: URL?, startOffset: TimeInterval
) {
  let originalTimelineNow = audioKit.currentTime
  playingInstrumentalForSongID = songID
  let aiTrackResume = max(0, originalTimelineNow - startOffset)
  KaraokeAudioProcessor.suppressVocalRemoval = true  // Disable DSP, use AI instead
  
  let strength = aiVocalStrength
  Task.detached { [weak self] in
    // Load buffers in background
    guard let instrBuf = AudioPlayerManager.readURLToBuffer(instrumentalURL) else { return }
    let vocBuf: AVAudioPCMBuffer? = vocalsURL.flatMap { AudioPlayerManager.readURLToBuffer($0) }
    
    await MainActor.run { [weak self] in
      self?.audioKit.playAIBuffers(
        instrumental: instrBuf,
        vocals: vocBuf,
        vocalsStrength: strength,
        startOffset: startOffset,
        startAt: aiTrackResume
      )
      self?.isPlaying = true
      self?.applyDSPSettings()
    }
  }
}
```

### Cache Structure

```
AudioCache/
├── Instrumental/
│   ├── {songID}.wav                    [Instrumental stem]
│   ├── {songID}.vocals.wav             [Vocals stem]
│   └── {songID}.offset                 [Start offset (sidecar)]
└── {songID}.mp3                        [Original audio cache]
```

---

## 7. USERDEFAULTS PERSISTENCE

### Audio Effects Settings

| Key | Default | Type | Purpose |
|-----|---------|------|---------|
| `nk.mlVocalRemoval` | false | Bool | Enable Spleeter AI separation |
| `nk.aiVocalStrength` | 1.0 | Double | AI vocals blend strength (0-1) |
| `nk.autoMixEnabled` | true | Bool | Auto-mix on track transitions |
| `nk.crossfadeEnabled` | false | Bool | Crossfade on track transitions |
| `nk.crossfadeSeconds` | 6.0 | Double | Crossfade duration (1-15s) |

### Loading Defaults (Init Logic)

```swift
@Published var mlVocalRemoval: Bool = UserDefaults.standard.bool(forKey: "nk.mlVocalRemoval")
@Published var aiVocalStrength: Float = AudioPlayerManager.loadAIVocalStrength()
@Published var autoMixEnabled: Bool = (UserDefaults.standard.object(forKey: "nk.autoMixEnabled") as? Bool ?? true)
@Published var crossfadeEnabled: Bool = (UserDefaults.standard.object(forKey: "nk.crossfadeEnabled") as? Bool ?? false)
@Published var crossfadeSeconds: Double = AudioPlayerManager.loadCrossfadeSeconds()

private static func loadAIVocalStrength() -> Float {
  let raw = UserDefaults.standard.object(forKey: "nk.aiVocalStrength") as? Double ?? 1.0
  return Float(min(1, max(0, raw)))
}

private static func loadCrossfadeSeconds() -> Double {
  let raw = UserDefaults.standard.object(forKey: "nk.crossfadeSeconds") as? Double ?? 6.0
  return min(15, max(1, raw))
}
```

---

## 8. AUDIO EFFECTS APPLICATION FLOW

### applyDSPSettings()

Called whenever any effect parameter changes:

```swift
private func applyDSPSettings() {
  let aiTakenOver = playingInstrumentalForSongID != nil
  
  // Only apply DSP vocal removal if AI is not active
  if karaokeMode && !aiTakenOver {
    audioKit.setVocalRemovalLevel(karaokeLevel)
  } else {
    audioKit.setVocalRemovalLevel(.off)
  }
  
  // Apply optional effects
  audioKit.setBassEnhanceStrength(bassEnhanceMode ? bassEnhanceStrength : 0)
  audioKit.setVocalEnhanceStrength(vocalEnhanceMode ? vocalEnhanceStrength : 0)
}
```

### AudioKit Layer

```swift
// In AudioKitPlayback.swift
func setVocalRemovalLevel(_ level: VocalRemovalLevel) {
  KaraokeAudioProcessor.vocalRemovalLevel = level  // Write to module static
}

func setBassEnhanceStrength(_ s: Float) {
  KaraokeAudioProcessor.bassEnhanceStrength = max(0, min(1, s))
}

func setVocalEnhanceStrength(_ s: Float) {
  KaraokeAudioProcessor.vocalEnhanceStrength = max(0, min(1, s))
}
```

### Processing Chain

```
Playback (MainPlayer/AuxPlayer)
  ↓
Mixer (blend main + aux for AI mode)
  ↓
KaraokeDSPUnit (vDSP: vocal removal, bass, vocal enhance)
  ↓
UserEQ (10-band parametric)
  ↓
Output
```

---

## 9. KEY FINDINGS & ARCHITECTURE SUMMARY

### ✅ What's Implemented

| Component | Status | Notes |
|-----------|--------|-------|
| **DSP Vocal Removal** | ✅ Complete | vDSP-based mid-side processing, 6-level intensity |
| **Bass Enhance** | ✅ Complete | Shelving + shaping, soft-clip protection |
| **Vocal Enhance** | ✅ Complete | Presence boost + vocal range emphasis |
| **10-Band EQ** | ✅ Complete | 11 presets + custom, AudioUnit-based |
| **AI Vocal Separation** | ✅ Complete (iOS 18+) | Spleeter v2, dual-stem output, progress tracking |
| **Next Track Playback** | ✅ Complete | Queue navigation, repeat modes, autoplay |
| **Mode Suppression** | ✅ Complete | Mutually exclusive effects via `_suppressDSPApply` |
| **Now Playing Integration** | ✅ Complete | MPNowPlayingInfoCenter updates |
| **Radio Mode** | ✅ Complete | Separate AVPlayer for streaming |
| **Download Management** | ✅ Complete | Resume support, partial file cleanup |

### ⚠️ What's NOT Implemented

| Component | Status | Notes |
|-----------|--------|-------|
| **Crossfade** | ❌ Stub only | UI properties exist, no audio implementation |
| **Auto-Mix** | ❌ Stub only | UI properties exist, no audio implementation |
| **Track Scheduling** | ❌ Missing | No upcoming track pre-loading |
| **Gapless Playback** | ❌ Missing | Hard cut between tracks |

### Architecture Layers

```
┌─────────────────────────────────────┐
│ UI Layer (Settings, Player Screen)  │  @Published properties
├─────────────────────────────────────┤
│ AudioPlayerManager (Singleton)       │  orchestrates playback, effects, AI
├─────────────────────────────────────┤
│ AudioKitPlayback                    │  FileLoading, mixing, AU routing
├─────────────────────────────────────┤
│ KaraokeAudioProcessor (vDSP Module) │  realtime DSP kernels
├─────────────────────────────────────┤
│ KaraokeDSPAudioUnit (Custom AU)     │  realtime render block
├─────────────────────────────────────┤
│ VocalSeparator (CoreML)             │  Spleeter v2 AI separation
├─────────────────────────────────────┤
│ AudioKit Engine                     │  synthesis, mixing, rendering
└─────────────────────────────────────┘
```

---

## 10. PRODUCTION READINESS ASSESSMENT

### Strengths
- ✅ Sophisticated vDSP implementation (SIMD-optimized)
- ✅ Proper realtime audio threading (no locks on audio thread)
- ✅ Module-level statics for lock-free DSP control
- ✅ Soft-clipping protection against distortion
- ✅ AI optional (graceful fallback to DSP)
- ✅ Proper UI -> audio thread decoupling
- ✅ Comprehensive effect presets

### Gaps for Karaoke App
- ❌ **No gapless playback** - hard silence between tracks
- ❌ **No crossfade implementation** - UI exists but no audio logic
- ❌ **No vocal-only output** - AI provides stems but no separate vocal-only mode
- ❌ **No real-time pitch correction/key shifting** - would be needed for professional karaoke
- ❌ **No mic input mixing** - user voice + track mixing not visible
- ❌ **No reverb/effects** - only EQ, bass boost, vocal enhancement

