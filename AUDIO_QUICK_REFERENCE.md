# iOS Karaoke App: Audio Pipeline - Quick Reference Guide

## TL;DR: 30-Second Summary

**Architecture:** AudioKit → Custom vDSP DSP Unit → 10-band EQ → Speaker

**Audio Modes (pick one):**
- 🎤 **Karaoke** (DSP vocal removal OR AI Spleeter stems) 
- 🔊 **Bass Enhance** (4x bass boost at 120Hz cutoff)
- 🎵 **Vocal Enhance** (vocal range isolation + presence)
- 🎚️ **10-Band EQ** (11 presets + custom)

**Key Files:**
- `AudioPlayerManager.swift` — orchestrates everything (1077 lines)
- `KaraokeAudioProcessor.swift` — vDSP kernels (370 lines)
- `KaraokeDSPAudioUnit.swift` — realtime audio unit (61 lines)
- `AudioKitPlayback.swift` — file loading + mixing (345 lines)
- `VocalSeparator.swift` — Spleeter v2 AI (227 lines)

---

## Quick Lookup: Properties & Their Purposes

### Playback Control
| Property | Type | Editable | Persists | Purpose |
|----------|------|----------|----------|---------|
| `currentSong` | `@Published Song?` | ❌ | ❌ | Currently playing track |
| `isPlaying` | `@Published Bool` | ❌ | ❌ | Play/pause state |
| `progress` | `@Published Double` | ✅ (seek) | ❌ | Playback progress 0-1 |
| `queue` | `@Published [Song]` | ❌ | ❌ | Up-next queue |
| `repeatMode` | `RepeatMode` | ✅ | ❌ | off/all/one |
| `isShuffled` | `@Published Bool` | ✅ | ❌ | Shuffle toggle |
| `autoplayEnabled` | `@Published Bool` | ✅ | ❌ | Auto-play trending when queue ends |

### Audio Effects - Karaoke (Vocal Removal)
| Property | Type | Range | Default | Persists | Purpose |
|----------|------|-------|---------|----------|---------|
| `karaokeMode` | `Bool` | — | false | ❌ | Enable/disable karaoke mode |
| `karaokeLevel` | `VocalRemovalLevel` | 0-4 | .strong (3) | ❌ | Intensity: off/light/medium/strong/maximum |
| `karaokeStrength` | `Float` | 0-1 | 0.85 | ❌ | Slider mapped to level |
| `mlVocalRemoval` | `Bool` | — | false | ✅ | Use Spleeter AI (iOS 18+) instead of DSP |
| `aiVocalStrength` | `Float` | 0-1 | 1.0 | ✅ | Vocals blend: 0=instrumental, 1=vocals |

### Audio Effects - Bass Enhance
| Property | Type | Range | Default | Persists | Purpose |
|----------|------|-------|---------|----------|---------|
| `bassEnhanceMode` | `Bool` | — | false | ❌ | Enable/disable bass boost |
| `bassEnhanceStrength` | `Float` | 0-1 | 0.5 | ❌ | Bass boost intensity (0=off, 1=max) |

### Audio Effects - Vocal Enhance
| Property | Type | Range | Default | Persists | Purpose |
|----------|------|-------|---------|----------|---------|
| `vocalEnhanceMode` | `Bool` | — | false | ❌ | Enable/disable vocal emphasis |
| `vocalEnhanceStrength` | `Float` | 0-1 | 0.5 | ❌ | Vocal boost intensity |

### Audio Effects - EQ
| Property | Type | Range | Default | Persists | Purpose |
|----------|------|-------|---------|----------|---------|
| `eqEnabled` | `Bool` | — | false | ❌ | Enable/disable 10-band EQ |
| `eqPreset` | `EQPreset` | enum(12) | .flat | ❌ | Preset selection (flat/bass/treble/vocal/rock/pop/jazz/electronic/classical/hiphop/loudness/custom) |
| `eqGainsDB` | `[Float]` | -∞ to +∞ | [0]*10 | ❌ | Individual band gains (dB) |

### Transitions (NOT IMPLEMENTED)
| Property | Type | Range | Default | Persists | Purpose |
|----------|------|-------|---------|----------|---------|
| `autoMixEnabled` | `Bool` | — | true | ✅ | ⚠️ Stored but no audio implementation |
| `crossfadeEnabled` | `Bool` | — | false | ✅ | ⚠️ Stored but no audio implementation |
| `crossfadeSeconds` | `Double` | 1-15 | 6.0 | ✅ | ⚠️ Stored but no audio implementation |

### Radio Mode
| Property | Type | Editable | Purpose |
|----------|------|----------|---------|
| `isRadioMode` | `@Published Bool` | ❌ | Radio stream playing |
| `radioArtworkURL` | `URL?` | ❌ | Current radio station artwork |

### Volume & Routing
| Property | Type | Range | Default | Purpose |
|----------|------|-------|---------|---------|
| `volume` | `@Published Double` | 0-1 | 1.0 | Master volume |
| `routeIcon` | `String` | — | "airplayaudio" | SF Symbol for current output |
| `routeName` | `String` | — | "" | Human-readable output name |

---

## Method Map: What Does What

### Entry Points for Playback
```swift
// Start playing a song (main entry point)
play(song: Song, context: [Song] = [])

// Skip to next track
playNextOrRandom()

// Skip to previous track
playPrevious()

// Seek to position
seek(to fraction: Double)  // 0.0-1.0

// Play/pause toggle
togglePlayPause()

// Start radio streaming
playRadio(streamURL: URL, song: Song, artworkURL: URL?)
```

### Mode Toggling
```swift
// Toggle modes (mutually exclusive)
karaokeMode.toggle()           // Enable/disable karaoke
bassEnhanceMode.toggle()       // Enable/disable bass boost
vocalEnhanceMode.toggle()      // Enable/disable vocal emphasis
eqEnabled.toggle()             // Enable/disable EQ
repeatMode = repeatMode.next() // Cycle: off → all → one → off
toggleShuffle()                // Toggle shuffle
toggleAutoplay()               // Toggle autoplay when queue ends
```

### Effect Adjustments (Realtime)
```swift
karaokeStrength = 0.75         // Adjust vocal removal (0-1)
karaokeLevel = .medium         // Set explicit level
mlVocalRemoval = true          // Switch to Spleeter AI
aiVocalStrength = 0.8          // Adjust AI vocals blend
bassEnhanceStrength = 0.7      // Adjust bass intensity
vocalEnhanceStrength = 0.6     // Adjust vocal emphasis
eqPreset = .vocal              // Switch EQ preset
eqGainsDB[3] = +3.0            // Boost 250Hz band by 3dB
```

---

## DSP Algorithm Reference

### Vocal Removal (Mid-Side Processing)

**Inputs:** Stereo L/R @ 44.1kHz

**Steps:**
1. Decompose to Mid/Side: `Mid = (L+R)/2`, `Side = (L-R)/2`
2. Bandpass filter Mid @ 250-6000 Hz (6-section biquad cascade)
3. Attenuate Mid by level.centerAttenuation (0.7-1.0)
4. Optionally boost for Maximum level (+25%)
5. Recombine: `L = Mid+Side`, `R = Mid-Side`

**Attenuation Factors:**
- Light: 0.7 (mild vocal reduction)
- Medium: 0.9 (moderate)
- Strong: 1.0 (aggressive)
- Maximum: 1.0 + 1.25× stereo boost

**CPU:** ~5-8% per channel (vDSP optimized)

### Bass Enhance (Shelving + Mixing)

**Inputs:** Stereo L/R

**Steps:**
1. Decompose to Mid/Side
2. Apply shaped gain: `shaped = strength² × (3 - 2×strength)`
3. Extract bass (lowpass 120Hz), mid, treble (highpass 9kHz)
4. Boost bass: `output = boosted_bass + mid + keep×treble`
5. Apply makeup gain to prevent clipping
6. Soft-clip via tanh() for smooth saturation

**Gain Curve (strength=1.0):**
- Bass boost: 4.0× (12dB)
- Makeup: 1.9× (5.6dB attenuation on mid/treble)

**CPU:** ~3-5% per channel

### Vocal Enhance (Range Emphasis)

**Inputs:** Stereo L/R

**Steps:**
1. Decompose to Mid/Side
2. Extract vocal range (250-6000 Hz)
3. Boost vocal band: `shaped × 3.0`
4. Presence boost on highs: `shaped × 1.2`
5. Attenuate side information (reduce stereo width)
6. Soft-clip

**Attenuation:** `sideAtt = 1.0 - shaped × 0.55`

**CPU:** ~3-5% per channel

---

## File Cache Locations

```
~/Library/Caches/
└── AudioCache/
    ├── {songID}.mp3              [Streamed & cached original]
    ├── {songID}.mp3.partial      [Resume support, cleaned on init]
    └── Instrumental/
        ├── {songID}.wav          [AI instrumental stem]
        ├── {songID}.vocals.wav   [AI vocals stem]
        └── {songID}.offset       [Timeline offset for mid-song activation]
```

**Size:** ~5-15MB per song (MP3), ~30-50MB per AI stem pair

---

## UserDefaults Keys

```swift
// Audio effects persistence
"nk.mlVocalRemoval"       // Bool, default: false
"nk.aiVocalStrength"      // Double 0-1, default: 1.0
"nk.autoMixEnabled"       // Bool, default: true (not implemented)
"nk.crossfadeEnabled"     // Bool, default: false (not implemented)
"nk.crossfadeSeconds"     // Double 1-15, default: 6.0 (not implemented)

// Other
"nk.token"                // Auth token from Discord
"nk.storageRegion"        // Override API region
```

---

## Realtime Thread Safety

✅ **Safe (lock-free):**
- Reading module-level statics in `KaraokeAudioProcessor`
- vDSP operations (SIMD kernels)
- Writing to float buffers

❌ **Not safe (would crash):**
- Memory allocation (`new`, `malloc`)
- Locks/semaphores
- Objective-C message sends
- NSString operations
- File I/O

**Separation of concerns:**
- **Main thread:** UI updates, file loading, decision-making
- **Audio thread:** Realtime DSP only, reads statics set by main thread
- **Background thread:** AI separation (via Task/async-await)

---

## EQ Preset Gains (10 Bands)

```
Band:      31.5Hz  63Hz  125Hz  250Hz  500Hz  1kHz  2kHz  4kHz  8kHz  16kHz
────────────────────────────────────────────────────────────────────────────
Flat       0       0     0      0      0      0     0     0     0     0
Bass       10      8     5      2      0      0     0     0     0     0
Treble     0       0     0      0      0      2     4     6     8     10
Vocal      -2      -1    0      3      6      6     4     2     0     -1
Rock       5       4     2      0      -2     -1    2     4     5     6
Pop        -1      2     4      5      3      0     -1    0     2     3
Jazz       3       2     0      2      4      4     2     3     4     3
Electronic 6       5     2      0      -2     2     1     4     6     7
Classical  4       3     2      1      -1     -1    0     2     3     4
Hip-Hop    7       6     3      1      0      0     1     2     4     3
Loudness   8       5     0      -2     -4     -2    0     3     6     8
Custom     [editable per band]
```

---

## Common Workflows

### Enable AI Vocal Separation (iOS 18+)
```swift
// 1. Check availability
if VocalSeparator.shared.isAvailable {
  // 2. Enable karaoke mode
  AudioPlayerManager.shared.karaokeMode = true
  
  // 3. Enable AI
  AudioPlayerManager.shared.mlVocalRemoval = true
  
  // 4. Play song
  AudioPlayerManager.shared.play(song: myTrack)
  
  // → AI separation starts in background
  // → Watch VocalSeparator.shared.progressFraction for UI
  // → Swaps to AI stems when ready
}
```

### Adjust Vocal Blend While Playing (AI Mode)
```swift
// Real-time, no latency
AudioPlayerManager.shared.aiVocalStrength = 0.5
// auxPlayer.volume = (1 - 0.5) = 0.5
// → Blends instrumental + vocals 50/50
```

### Fade Between Effects
```swift
// Effect modes are mutually exclusive, no transition DSP
// To "fade" between effects: use Timer + property animation

Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
  let newStrength = min(1.0, oldStrength + 0.05)
  AudioPlayerManager.shared.karaokeStrength = newStrength
}

// Or use SwiftUI Animation:
withAnimation(.easeInOut(duration: 0.5)) {
  AudioPlayerManager.shared.karaokeStrength = targetValue
}
```

### Apply Custom EQ
```swift
// Start with preset
AudioPlayerManager.shared.eqPreset = .vocal  // Load vocal gains

// Then adjust individual bands
var gains = AudioPlayerManager.shared.eqGainsDB
gains[0] += 2.0  // Boost 31.5Hz by 2dB more
gains[9] -= 1.0  // Cut 16kHz by 1dB
AudioPlayerManager.shared.eqGainsDB = gains

// → eqPreset auto-changes to .custom
```

### Queue Navigation with Shuffle
```swift
// Shuffle play from array
AudioPlayerManager.shared.playShuffled(from: songs)

// Toggle shuffle mid-queue
AudioPlayerManager.shared.toggleShuffle()
// → Shuffles queue, keeps current song at head

// Back to original order
AudioPlayerManager.shared.toggleShuffle()
// → Restores from originalQueue backup
```

---

## Performance Metrics

| Operation | CPU | Memory | Latency |
|-----------|-----|--------|---------|
| Vocal Removal (DSP) | 5-8% | ~64KB buffers | <1ms |
| Bass Enhance | 3-5% | ~64KB buffers | <1ms |
| Vocal Enhance | 3-5% | ~64KB buffers | <1ms |
| 10-band EQ | 2-4% | ~32KB buffers | <1ms |
| **Total DSP** | **~15%** | **~160KB** | **<1ms** |
| AI Separation (Spleeter) | 80-95% (GPU preferred) | 400-600MB | 2-5 min for 3-5min song |
| File Download @ 2Mbps | varies | <1MB | ~20s per song |

---

## Debugging Tips

### Check if DSP is active
```swift
let dspActive = KaraokeAudioProcessor.hasAnyEffect
print("DSP active: \(dspActive)")
```

### Monitor AI separation progress
```swift
@StateObject var separator = VocalSeparator.shared

VStack {
  if let songID = separator.processingSongID {
    ProgressView(value: Double(separator.progressFraction))
    Text("Separating: \(songID)")
  }
}
```

### Check which mode is active
```swift
let mode = (
  AudioPlayerManager.shared.karaokeMode ? "Karaoke" :
  AudioPlayerManager.shared.bassEnhanceMode ? "Bass" :
  AudioPlayerManager.shared.vocalEnhanceMode ? "Vocal" :
  AudioPlayerManager.shared.eqEnabled ? "EQ" :
  "None"
)
print("Active mode: \(mode)")
```

### Verify audio file playback
```swift
let kit = AudioPlayerManager.shared.audioKit
print("Playing: \(kit.isPlaying)")
print("Duration: \(kit.duration)s")
print("Current time: \(kit.currentTime)s")
print("Mode: \(kit.mode == .aiMix ? "AI (dual stems)" : "Single file")")
```

---

## Not Implemented (Stubs Only)

⚠️ These properties are persisted but have **zero audio implementation**:
- Crossfade transitions between tracks
- Auto-mix blending
- Gapless playback
- Upcoming track pre-loading
- Vocal-only output (separate from instrumental)
- Pitch/key shifting
- Microphone input mixing

If you need these, they'd require:
1. Schedule upcoming track prep 3-5s before end
2. Implement fade-in/fade-out envelopes in DSP
3. Crossfade mixing of two tracks
4. Separate mic input + karaoke track stem mixing

