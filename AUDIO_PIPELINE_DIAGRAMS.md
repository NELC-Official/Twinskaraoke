# iOS Karaoke App: Audio Pipeline - Visual Diagrams

## 1. High-Level Audio Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         UI Layer                                  │
│  (Settings, Player Controls, Progress Indicators)                 │
│                    @Published properties                          │
└────────────────────────────┬─────────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────────┐
│              AudioPlayerManager (Singleton)                       │
│                                                                    │
│  • play(song, context) - main entry point                        │
│  • playNextOrRandom() - track navigation                         │
│  • applyDSPSettings() - effect routing                           │
│  • applyMLSeparationIfNeeded() - AI separation trigger           │
│  • swapToAITrack() - stem mixing                                 │
└────────────────────────────┬─────────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────────┐
│              AudioKitPlayback (File Loading)                      │
│                                                                    │
│  • loadIntoPlayer() - MP3 decode with fallbacks                  │
│  • playAIBuffers() - load instrumental + vocals stems            │
│  • playAI() - load AI track URLs                                 │
│  • seek() - position control with AI offset handling             │
└────────────────────────────┬─────────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────────┐
│                 AudioKit Engine                                    │
│                                                                    │
│     MainPlayer          AuxPlayer                                 │
│    (Original or      (Vocals for AI                              │
│     Instrumental)     mode only)                                  │
│            \              /                                        │
│             \            /                                         │
│              ▼          ▼                                          │
│              ┌────────────┐                                        │
│              │   Mixer    │                                        │
│              └──────┬─────┘                                        │
│                     │                                              │
└─────────────────────┼──────────────────────────────────────────────┘
                      │
┌─────────────────────▼──────────────────────────────────────────────┐
│           KaraokeDSPAudioUnit (Custom V3 Audio Unit)                │
│                                                                     │
│  Reads: KaraokeAudioProcessor module-level statics (lock-free)    │
│  Runs on: Realtime audio thread (~44.1kHz, every ~23µs)           │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  processInPlace(bufferList, numFrames)                      │   │
│  │                                                              │   │
│  │  if vocalRemovalLevel != .off:                              │   │
│  │     applyVocalRemoval() - mid-side bandpass processing      │   │
│  │                                                              │   │
│  │  if bassEnhanceStrength > 0:                                │   │
│  │     applyBassEnhance() - shelving + boost                   │   │
│  │                                                              │   │
│  │  if vocalEnhanceStrength > 0:                               │   │
│  │     applyVocalEnhance() - presence + range emphasis         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────┬──────────────────────────────────────────────┘
                      │
┌─────────────────────▼──────────────────────────────────────────────┐
│              UserEQ (10-band Parametric)                            │
│                                                                     │
│  Bands: 31.5Hz, 63Hz, 125Hz, 250Hz, 500Hz,                        │
│         1kHz, 2kHz, 4kHz, 8kHz, 16kHz                             │
│                                                                     │
│  Presets: Flat, Bass, Treble, Vocal, Rock, Pop, Jazz,             │
│           Electronic, Classical, Hip-Hop, Loudness, Custom         │
└─────────────────────┬──────────────────────────────────────────────┘
                      │
                      ▼
              ┌──────────────┐
              │   Speakers   │
              │ / Headphones │
              └──────────────┘
```

---

## 2. Audio Effects Modes (Mutually Exclusive)

```
┌─────────────────────────────────────────────────────────────┐
│  Audio Effects Mode Controller                               │
│                                                              │
│  Suppression Flag: _suppressDSPApply                        │
│  (Prevents cascade loops when toggling competing modes)     │
└─────────────────────────────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
    ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
    │   Karaoke   │   │    Bass     │   │   Vocal     │
    │    Mode     │   │   Enhance   │   │  Enhance    │
    │             │   │             │   │             │
    │ • Off       │   │ • Off       │   │ • Off       │
    │ • Light     │   │ • 0.0-1.0   │   │ • 0.0-1.0   │
    │ • Medium    │   │  Strength   │   │  Strength   │
    │ • Strong    │   │             │   │             │
    │ • Maximum   │   └─────────────┘   └─────────────┘
    │             │
    │ DSP: Mid-   │      Fallback to DSP only
    │ Side band-  │      (iOS <18 or no Spleeter)
    │ pass @      │
    │ 250-6kHz    │
    │             │
    │ AI: Sple-   │      (iOS 18+ only)
    │ eter v2     │      Produces dual stems:
    │ CoreML      │      • Instrumental.wav
    │ separation  │      • Vocals.wav
    └─────────────┘
         │
         └─────────────────────────────────────┐
                                               │
                    ┌──────────────────────────┼──────────┐
                    │                          │          │
                    ▼                          ▼          ▼
             ┌─────────────┐           ┌─────────────┐  │ EQ
             │   Mutually  │           │   Mutually  │  │ (Always
             │  Exclusive  │           │  Exclusive  │  │  separate)
             │  At UI level│           │  At UI level│  │
             └─────────────┘           └─────────────┘  │
                                                        │
                                                        ▼
                                                  ┌─────────────┐
                                                  │ 10-Band EQ  │
                                                  │   31.5Hz    │
                                                  │   -16kHz    │
                                                  │             │
                                                  │ 11 Presets  │
                                                  │ + Custom    │
                                                  └─────────────┘

RULE: Enabling Mode A auto-disables competing Modes B & C
      (via _suppressDSPApply flag suppression mechanism)
```

---

## 3. Vocal Removal Algorithm (DSP)

```
Stereo Input (L, R)
      │
      ▼
┌──────────────────────┐
│ Mid-Side Decompose   │
│                      │
│ Mid = (L + R) / 2    │  [Centered: vocals, drums]
│ Side = (L - R) / 2   │  [Stereo: effects, width]
└────────┬─────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ Biquad Cascade Filter (Mid only) │
│                                  │
│ 3× Highpass @ 250 Hz (Q=0.7071)  │
│ 3× Lowpass @ 6 kHz (Q=0.7071)    │
│                                  │
│ → Isolates vocal frequency band  │
│   (250-6000 Hz)                  │
└────────────┬─────────────────────┘
             │
             ▼
    ┌──────────────────┐
    │  Filtered Mid    │
    │  (Vocal extract) │
    └────────┬─────────┘
             │
             ▼
┌────────────────────────────────────┐
│ Center Attenuation                  │
│                                     │
│ att_factor = VocalRemovalLevel      │
│              centerAttenuation      │
│                                     │
│ VocalRemovalLevel:                  │
│   • Light     → att = 0.7           │
│   • Medium    → att = 0.9           │
│   • Strong    → att = 1.0           │
│   • Maximum   → att = 1.0 + boost   │
│                                     │
│ Output = Mid - (att * Filtered_Mid) │
└────────┬───────────────────────────┘
         │
         ▼
    ┌─────────────────┐
    │ (Optional)      │
    │ Maximum Boost   │
    │                 │
    │ if Maximum:     │
    │   Mid ×= 1.25   │
    │   Side ×= 1.25  │
    └────────┬────────┘
             │
             ▼
┌──────────────────────┐
│ Mid-Side Recombine   │
│                      │
│ L = Mid + Side       │
│ R = Mid - Side       │
└────────┬─────────────┘
         │
         ▼
    Stereo Output (L, R)
    [Vocal-reduced]
```

---

## 4. Bass Enhance Algorithm (DSP)

```
Stereo Input (L, R)
      │
      ▼
┌──────────────────────┐
│ Mid-Side Decompose   │
└────────┬─────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Gain Shaping Curve                  │
│                                     │
│ shaped = strength² × (3 - 2×strength)│
│                                     │
│ Where strength = slider (0.0-1.0)   │
│                                     │
│ Result:                             │
│ • strength=0.5 → shaped ≈ 0.375    │
│ • strength=1.0 → shaped = 1.0      │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Mid-Channel Decomposition           │
│                                     │
│ 1-pole lowpass @ 120 Hz (bassLow)   │
│   → Extract deep bass               │
│                                     │
│ 1-pole lowpass @ 9 kHz (highPass)   │
│   → Extract treble above 9kHz       │
│                                     │
│ Mid_mid = Mid - bassLow - highPass  │
│   → Isolated 120Hz-9kHz midrange    │
└────────┬────────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Boost Calculation                   │
│                                     │
│ bassBoost = 1.0 + shaped × 3.0      │
│ makeup = 1.0 + shaped × 0.9         │
│ keep = 1.0 - shaped × 0.6           │
│                                     │
│ Result for strength=1.0:            │
│   bassBoost = 4.0 (4× boost)        │
│   makeup = 1.9 (attenuate others)   │
└────────┬────────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Mixing & Makeup Gain                │
│                                     │
│ boosted_bass = bassLow × bassBoost  │
│ output_mid = boosted_bass +         │
│              mid_mid +              │
│              (keep × highPass)      │
│                                     │
│ L = (output_mid + Side) × makeup    │
│ R = (output_mid - Side) × makeup    │
└────────┬────────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Soft Clipping (Distortion Control)  │
│                                     │
│ L = tanh(L)  [smooth saturation]    │
│ R = tanh(R)  [smooth saturation]    │
└────────┬────────────────────────────┘
         │
         ▼
    Stereo Output (L, R)
    [Bass-enhanced, controlled]
```

---

## 5. AI Vocal Separation Workflow (iOS 18+)

```
┌─────────────────────────────────────────┐
│ User enables Karaoke Mode               │
│   + mlVocalRemoval = true               │
│                                         │
│ → applyMLSeparationIfNeeded()           │
└────────────┬────────────────────────────┘
             │
             ▼
    ┌─────────────────────┐
    │ Check Availability  │
    │                     │
    │ if iOS < 18 or      │
    │ Spleeter unavail:   │
    │   → Use DSP only    │
    └────────┬────────────┘
             │
             ▼
   ┌──────────────────────────┐
   │ Check AI Stem Cache      │
   │                          │
   │ AudioCache/Instrumental/ │
   │  ├─ {songID}.wav         │
   │  ├─ {songID}.vocals.wav  │
   │  └─ {songID}.offset      │
   │                          │
   │ if all exist → skip to   │
   │ "Swap to AI" below       │
   └──────┬──────────────────┘
          │
          ▼
    ┌─────────────────────┐
    │ Find Source Audio   │
    │                     │
    │ Check in order:     │
    │ 1. Downloaded       │
    │ 2. Cached (MP3)     │
    │ 3. Poll (2s retry)  │
    │                     │
    │ Timeout: 600s       │
    └────────┬────────────┘
             │
             ▼
  ┌───────────────────────────┐
  │ Optional: Trim Audio      │
  │                           │
  │ if playback already       │
  │ started (currentTime>1s): │
  │   → Export tail from      │
  │     currentTime→end       │
  │   → Skip processing the   │
  │     already-heard part    │
  │                           │
  │ Saves separation time     │
  │ & CPU cost               │
  └────────┬──────────────────┘
           │
           ▼
  ┌──────────────────────────────┐
  │ Spleeter v2 Separation       │
  │ (async generator)            │
  │                              │
  │ Input:  Audio (MP3/M4A)      │
  │ Model:  Spleeter2Model.ml    │
  │ Output: 2 WAV stems          │
  │                              │
  │ CoreML runs on:              │
  │ • GPU (preferred)            │
  │ • Neural Engine (A-series)   │
  │ • CPU (fallback)             │
  │                              │
  │ Progress: reported per       │
  │ batch (~5-10% intervals)     │
  │                              │
  │ Produces:                    │
  │ • instrumental.wav           │
  │ • vocals.wav                 │
  │                              │
  │ (Both 44.1kHz, mono/stereo)  │
  └────────┬─────────────────────┘
           │
           ▼
  ┌────────────────────────────┐
  │ Cache Stems & Metadata     │
  │                            │
  │ Move to:                   │
  │ • {songID}.wav (instr.)    │
  │ • {songID}.vocals.wav      │
  │ • {songID}.offset (meta)   │
  │                            │
  │ offset = when separation   │
  │ started (for timeline      │
  │ alignment if mid-song)     │
  └────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│ Swap to AI Track                  │
│                                  │
│ 1. Load buffers in background    │
│ 2. KaraokeAudioProcessor         │
│    .suppressVocalRemoval = true  │
│    (Disable DSP, use AI stems)   │
│                                  │
│ 3. AudioKit.playAIBuffers()      │
│    mainPlayer ← instrumental     │
│    auxPlayer ← vocals            │
│    auxPlayer.volume = 1.0 -      │
│                   aiVocalStrength│
│                                  │
│ 4. Sync playback position        │
│    adjust = currentTime -        │
│              startOffset         │
│    seek(mainPlayer, adjust)      │
│    seek(auxPlayer, adjust)       │
└──────────────────────────────────┘
           │
           ▼
    ┌──────────────────┐
    │ Real-time mixing │
    │                  │
    │ aiVocalStrength  │
    │ slider: 0-1      │
    │                  │
    │ • 0.0 = instr    │
    │   only           │
    │ • 0.5 = blend    │
    │ • 1.0 = vocals   │
    │   only           │
    │                  │
    │ (no UI fade, is  │
    │  instant via     │
    │  volume         │
    │  crossfade)      │
    └─────────────────┘
```

---

## 6. Track Navigation Flow

```
┌────────────────────────────────────┐
│  User initiates playback           │
│  play(song, context:[queue])       │
└────────┬─────────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ 1. Stop radio (if active)          │
│ 2. Report play count (telemetry)   │
│ 3. Update currentSong              │
│ 4. Set queue from context          │
│ 5. Handle shuffle if enabled       │
└────────┬─────────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Locate audio file:                 │
│                                    │
│ 1. Check DownloadManager.localURL  │
│    (user-downloaded full file)     │
│                                    │
│ 2. Check AudioCache/{songID}.mp3   │
│    (streamed & cached)             │
│                                    │
│ 3. Download from remote if needed  │
│    (AudioDownloadSession with      │
│     resume support)                │
└────────┬─────────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ startPlayingFile(url)              │
│                                    │
│ • Play via AudioKit                │
│ • Set isPlaying = true             │
│ • Update Now Playing info          │
│ • Apply ML separation if enabled   │
└────────┬─────────────────────────────┘
         │
         ▼
     ┌─────────────────────────┐
     │ AudioKit plays file...  │
     │                         │
     │ (MainPlayer renders)    │
     └──────────┬──────────────┘
                │
                ├─ DSP effects applied
                │  (KaraokeDSPUnit)
                │
                ├─ EQ applied (UserEQ)
                │
                └─ Output to speaker
                   / headphone jack
                   / AirPlay
                   / Bluetooth speaker
                
                   ▼
                
         [Song plays ~3-5 min]
         
                   │
                   │
                   ▼
         Track completion
         audioKit.onPlaybackEnded
         fires callback
                   │
                   ▼
            playNextOrRandom()
                   │
     ┌─────────┬──────┬──────┬─────────┐
     │         │      │      │         │
     ▼         ▼      ▼      ▼         ▼
┌────────┐ ┌────┐ ┌─────┐ ┌─────┐ ┌──────┐
│Repeat  │ │Next│ │Loop │ │Auto-│ │Stop  │
│One: Repl │Track │All  │ │play │ │Play  │
│current   │in    │to   │ │Trend│ │      │
│          │queue │first│ │ing  │ │      │
└────────┘ └─┬──┘ └──┬──┘ └─┬───┘ └─┬────┘
             │       │       │      │
             └───────┴───────┴──────┘
                     │
                     ▼
              play(nextSong)
              [Cycle repeats]
```

---

## 7. UserDefaults Persistence Map

```
UserDefaults (iOS Keychain-like storage)
│
├─ nk.mlVocalRemoval (Bool)
│  Default: false
│  Saves: User preference for AI separation toggle
│  Applies: On next session when karaoke mode + iOS 18+
│
├─ nk.aiVocalStrength (Double)
│  Range: 0.0 - 1.0
│  Default: 1.0 (vocals full)
│  Saves: After slider adjustment
│  Applies: Real-time via auxPlayer.volume = (1 - strength)
│
├─ nk.autoMixEnabled (Bool)
│  Default: true
│  Saves: User preference for track transitions
│  Status: ⚠️ STORED but NOT IMPLEMENTED
│
├─ nk.crossfadeEnabled (Bool)
│  Default: false
│  Saves: User preference
│  Status: ⚠️ STORED but NOT IMPLEMENTED
│
├─ nk.crossfadeSeconds (Double)
│  Range: 1.0 - 15.0
│  Default: 6.0
│  Saves: After slider adjustment
│  Status: ⚠️ STORED but NOT IMPLEMENTED
│
└─ nk.token (String)
   Saves: Auth token from Discord login
   Used: API requests for authorized features
```

---

## 8. Real-time Audio Thread Safety

```
Main Thread (UI, Combine)
│
├─ AudioPlayerManager updates @Published properties
├─ User adjusts karaokeStrength slider
├─ Combines didSet → applyDSPSettings()
│
│ [Write to module statics]
│ │
│ └─→ audioKit.setVocalRemovalLevel(level)
│     audioKit.setBassEnhanceStrength(bass)
│     audioKit.setVocalEnhanceStrength(vocal)
│
└─→ KaraokeAudioProcessor module statics:
    ├─ vocalRemovalLevel
    ├─ bassEnhanceStrength
    ├─ vocalEnhanceStrength
    └─ suppressVocalRemoval
    
    [Simple writes, no atomic ops needed]


Audio Thread (Realtime, ~23µs deadline per sample)
│
├─ Every 44.1kHz sample:
│  │
│  └─ KaraokeDSPUnit.internalRenderBlock() fires
│     │
│     ├─ READ: module statics (no locks!)
│     ├─ Calls: KaraokeAudioProcessor.processInPlace()
│     ├─ vDSP operations (SIMD, lock-free)
│     └─ NO allocations, NO synchronization
│
└─ Completion: ~2-5 samples later
   (Low priority thread doesn't block realtime)


✅ Thread-safe because:
   • Module statics are simple reads
   • No memory allocation on audio thread
   • vDSP operations are wait-free
   • No Combine subscriptions on audio thread
   • Main thread writes don't require synchronization
     (modern CPUs have sufficient memory barriers)
```

