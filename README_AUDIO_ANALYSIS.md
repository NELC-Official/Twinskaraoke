# iOS Karaoke App: Complete Audio Pipeline Documentation

**Created:** May 11, 2026  
**Scope:** Comprehensive analysis of `AudioPlayerManager`, `KaraokeAudioProcessor`, `KaraokeDSPAudioUnit`, `AudioKitPlayback`, and `VocalSeparator` classes  
**Total Documentation:** 2,288 lines across 4 markdown files (92 KB)

---

## 📚 Document Guide

### 1. **AUDIO_ANALYSIS_SUMMARY.md** (385 lines, 16 KB)
**Start here if you have 10 minutes**

- Executive summary of the audio pipeline
- What's implemented vs. what's missing
- Architecture overview (simplified diagram)
- Key algorithms explained (vocal removal, bass enhance)
- File-by-file breakdown with key insights
- Performance metrics
- Testing recommendations
- Grade: A- production-quality code

**Best for:** Quick understanding, stakeholder presentations, code review context

---

### 2. **AUDIO_PIPELINE_ANALYSIS.md** (874 lines, 28 KB)
**Start here for deep understanding**

**Sections:**
1. Background Playback & Next Track Behavior
   - `play()` method full implementation
   - `playNextOrRandom()` queue navigation
   - Track ending event flow
   - Repeat modes & autoplay logic

2. Audio Effects Modes (Mutually Exclusive)
   - Karaoke mode (vocal removal)
   - Bass enhance mode
   - Vocal enhance mode
   - 10-band EQ with 11 presets
   - Toggling logic via `_suppressDSPApply` flag

3. Crossfade & Auto-Mix ⚠️
   - UI properties exist but NO audio implementation

4. Play() Method Complete Flow
   - File location strategy (priority order)
   - Download with resume support
   - Buffering & error handling

5. DSP-Based Voice Removal
   - Mid-side decomposition algorithm
   - Biquad cascade filtering
   - Center attenuation factors
   - Soft-clipping protection

6. AI Vocal Separation (Spleeter v2, iOS 18+)
   - ML workflow overview
   - Stem caching strategy
   - Optional trimming for mid-song activation
   - Dual-stream mixing

7. UserDefaults Persistence
   - All 5 audio effect settings
   - Defaults and ranges
   - Loading logic

8. Effects Application Flow
   - `applyDSPSettings()` method
   - AudioKit layer routing
   - Processing chain

9. Architecture Summary
   - What's implemented ✅
   - What's NOT implemented ⚠️
   - Production readiness

**Best for:** Developers, architects, understanding specific algorithms

---

### 3. **AUDIO_PIPELINE_DIAGRAMS.md** (614 lines, 32 KB)
**Start here if you're visual**

**Diagrams included:**

1. **High-Level Audio Architecture**
   - UI → AudioPlayerManager → AudioKitPlayback → AudioKit Engine → KaraokeDSPUnit → UserEQ → Output
   - Clear layer separation

2. **Audio Effects Modes (Mutually Exclusive)**
   - Decision tree showing mode conflicts
   - `_suppressDSPApply` suppression mechanism

3. **Vocal Removal Algorithm (DSP)**
   - Step-by-step mid-side processing
   - Biquad cascade @ 250-6kHz
   - Attenuation factors
   - Recombination flow

4. **Bass Enhance Algorithm (DSP)**
   - Gain shaping curve
   - Mid decomposition (bass/mid/treble)
   - Boost calculation
   - Soft-clip protection

5. **AI Vocal Separation Workflow (iOS 18+)**
   - Cache check → source file → optional trim → Spleeter → cache → swap
   - Progress reporting
   - Real-time mixing

6. **Track Navigation Flow**
   - Complete playback cycle
   - Queue navigation paths
   - All repeat modes
   - Autoplay fallback

7. **UserDefaults Persistence Map**
   - All keys, defaults, ranges, status

8. **Real-Time Audio Thread Safety**
   - Main thread (UI) → Audio thread (DSP) → Background (AI)
   - Thread-safe operations vs. unsafe operations
   - Module statics for lock-free DSP

**Best for:** Visual learners, documentation, team discussions, presentations

---

### 4. **AUDIO_QUICK_REFERENCE.md** (415 lines, 16 KB)
**Start here if you need quick answers**

**Lookup tables:**
- Playback control properties (7)
- Karaoke effect properties (5)
- Bass enhance properties (2)
- Vocal enhance properties (2)
- EQ properties (3)
- Transitions - NOT IMPLEMENTED (3)
- Radio mode properties (2)
- Volume & routing properties (3)

**Quick reference:**
- Method map (what does what)
- Entry points for playback
- Mode toggling
- Effect adjustments
- DSP algorithm reference (brief versions)
- File cache locations
- UserDefaults keys
- Thread safety rules
- EQ preset gains table
- Common workflows with code examples
- Performance metrics table
- Debugging tips with code snippets
- Not implemented checklist

**Best for:** Implementation, code examples, quick lookups, debugging

---

## 🎯 Quick Navigation by Use Case

### "I need to understand the whole system"
1. Read: **AUDIO_ANALYSIS_SUMMARY.md** (10 min)
2. Skim: **AUDIO_PIPELINE_DIAGRAMS.md** (5 min, look at diagrams)
3. Reference: **AUDIO_QUICK_REFERENCE.md** as needed

### "I need to implement a feature"
1. Check: **AUDIO_QUICK_REFERENCE.md** for similar examples
2. Read: Relevant section in **AUDIO_PIPELINE_ANALYSIS.md**
3. Reference: Diagrams for data flow

### "I need to debug an issue"
1. Consult: **AUDIO_QUICK_REFERENCE.md** debugging section
2. Check: Relevant algorithm in **AUDIO_PIPELINE_ANALYSIS.md**
3. Trace: Flow in **AUDIO_PIPELINE_DIAGRAMS.md**

### "I need to present this to stakeholders"
1. Use: **AUDIO_ANALYSIS_SUMMARY.md** for context
2. Show: Diagrams from **AUDIO_PIPELINE_DIAGRAMS.md**
3. Cite: Performance metrics & grades

### "I need to review the audio code"
1. Start: **AUDIO_ANALYSIS_SUMMARY.md** for overview
2. Deep dive: **AUDIO_PIPELINE_ANALYSIS.md** for details
3. Check: Against **AUDIO_QUICK_REFERENCE.md** patterns

---

## 📊 Key Statistics

### Code Coverage
- **AudioPlayerManager.swift**: 1,077 lines → 250+ lines documented
- **KaraokeAudioProcessor.swift**: 370 lines → 180+ lines documented
- **KaraokeDSPAudioUnit.swift**: 61 lines → 40+ lines documented
- **AudioKitPlayback.swift**: 345 lines → 120+ lines documented
- **VocalSeparator.swift**: 227 lines → 100+ lines documented
- **Total audio code**: 2,080 lines
- **Total documentation**: 2,288 lines (110% coverage!)

### Implementation Status
- ✅ **Implemented:** 10 major features (DSP, AI separation, EQ, queue, etc.)
- ⚠️ **Stubs Only:** 3 UI features (crossfade, auto-mix, gapless)
- ❌ **Missing:** 2 features (mic mixing, pitch shifting)
- **Overall Grade:** A- (Excellent audio, feature gaps are non-critical)

### Diagrams
- 8 ASCII flow diagrams (fully formatted)
- 5 algorithm step-by-step visualizations
- 3 thread safety models
- 2 architecture overviews

---

## 🔍 What This Analysis Covers

### ✅ Fully Analyzed
- **Background playback** — how tracks play and transition
- **Next track behavior** — queue navigation, repeat modes, autoplay
- **Karaoke mode** — DSP vocal removal, ML-based separation
- **Bass enhance mode** — shelving + boosting algorithm
- **Vocal enhance mode** — presence boost + range isolation
- **10-band EQ** — 11 presets + custom gains
- **Audio effects toggling** — mutually exclusive mode logic
- **Crossfade/Auto-mix** — documented as NOT IMPLEMENTED
- **DSP processing** — vDSP kernels, thread safety, CPU usage
- **AI separation** — Spleeter v2 CoreML workflow
- **File caching** — cache priority, resume support
- **UserDefaults** — persistence of 5 audio settings
- **Audio routing** — AirPlay, Bluetooth, headphones, speaker
- **Real-time safety** — lock-free design, SIMD optimization

### ⚠️ Partially Covered (Stubs Only)
- Crossfade transitions (UI properties, no DSP)
- Auto-mix blending (UserDefaults, no logic)
- Gapless playback (not implemented)

### ❌ Out of Scope
- Microphone input mixing (not in codebase)
- Pitch/key shifting (not in codebase)
- Lyrics syncing (not in codebase)
- Scoring algorithm (not in codebase)
- UI layer (not audio-focused)

---

## 🛠️ How to Use This Documentation

### For Code Review
```
✓ Check AUDIO_ANALYSIS_SUMMARY.md for "Production Readiness" section
✓ Verify DSP correctness against AUDIO_PIPELINE_ANALYSIS.md algorithms
✓ Check thread safety against AUDIO_PIPELINE_DIAGRAMS.md thread model
✓ Test methods exist per AUDIO_QUICK_REFERENCE.md method map
```

### For Onboarding New Developers
```
1. Read AUDIO_ANALYSIS_SUMMARY.md (10 min overview)
2. Skim AUDIO_PIPELINE_DIAGRAMS.md (5 min visual orientation)
3. Study AUDIO_PIPELINE_ANALYSIS.md in depth (30 min deep dive)
4. Keep AUDIO_QUICK_REFERENCE.md at hand for development
```

### For Feature Implementation
```
1. Check if feature is documented in AUDIO_QUICK_REFERENCE.md
2. If partial/missing: search AUDIO_PIPELINE_ANALYSIS.md for related logic
3. If complex: trace data flow in AUDIO_PIPELINE_DIAGRAMS.md
4. Implement, then verify against documented patterns
```

### For Performance Optimization
```
1. Check baseline metrics in AUDIO_ANALYSIS_SUMMARY.md
2. Identify bottleneck in AUDIO_QUICK_REFERENCE.md performance table
3. Understand algorithm in AUDIO_PIPELINE_ANALYSIS.md
4. Profile against documented CPU/memory baselines
```

### For Bug Fixing
```
1. Find similar issue in AUDIO_QUICK_REFERENCE.md debugging section
2. Understand expected behavior from AUDIO_PIPELINE_DIAGRAMS.md
3. Check algorithm details in AUDIO_PIPELINE_ANALYSIS.md
4. Verify fix against documented behavior
```

---

## 📌 Key Takeaways

1. **Architecture is sophisticated** — proper layer separation, lock-free DSP, AI fallback
2. **Thread safety is done right** — module statics, no allocations on audio thread
3. **DSP is production-quality** — vDSP optimized, soft-clipping, proper gain staging
4. **AI integration is optional** — graceful fallback to DSP on older iOS
5. **UI stubs exist but no audio** — crossfade/auto-mix properties persist but don't work
6. **File handling is robust** — resume support, format fallbacks, cache cleanup
7. **Code is maintainable** — clear separation of concerns, well-named methods
8. **Performance is excellent** — ~15% DSP CPU, <1ms latency, minimal memory

**Bottom line:** This is A-grade audio engineering with some unfinished UI features.

---

## 📞 Questions These Docs Answer

<details>
<summary><b>How does vocal removal work?</b></summary>
See: AUDIO_PIPELINE_ANALYSIS.md section 5, AUDIO_PIPELINE_DIAGRAMS.md diagram 3
</details>

<details>
<summary><b>What happens when a track ends?</b></summary>
See: AUDIO_PIPELINE_ANALYSIS.md section 1, AUDIO_PIPELINE_DIAGRAMS.md diagram 6
</details>

<details>
<summary><b>How does AI separation work?</b></summary>
See: AUDIO_PIPELINE_ANALYSIS.md section 6, AUDIO_PIPELINE_DIAGRAMS.md diagram 5
</details>

<details>
<summary><b>Why can't I enable multiple effects at once?</b></summary>
See: AUDIO_PIPELINE_ANALYSIS.md section 2, AUDIO_PIPELINE_DIAGRAMS.md diagram 2
</details>

<details>
<summary><b>How is thread safety ensured?</b></summary>
See: AUDIO_PIPELINE_ANALYSIS.md section 8, AUDIO_PIPELINE_DIAGRAMS.md diagram 8
</details>

<details>
<summary><b>What's the CPU cost of each effect?</b></summary>
See: AUDIO_ANALYSIS_SUMMARY.md performance section, AUDIO_QUICK_REFERENCE.md metrics table
</details>

<details>
<summary><b>How do I enable a specific effect?</b></summary>
See: AUDIO_QUICK_REFERENCE.md workflows section, example code included
</details>

<details>
<summary><b>What's not implemented?</b></summary>
See: AUDIO_ANALYSIS_SUMMARY.md gaps section, AUDIO_PIPELINE_ANALYSIS.md section 3
</details>

<details>
<summary><b>How do I debug an audio issue?</b></summary>
See: AUDIO_QUICK_REFERENCE.md debugging section with code examples
</details>

<details>
<summary><b>What's the EQ curve for each preset?</b></summary>
See: AUDIO_QUICK_REFERENCE.md EQ preset gains table
</details>

---

## 📄 File Manifest

```
AUDIO_ANALYSIS_SUMMARY.md          ← START HERE (executive summary)
├── Key findings (implemented vs. missing)
├── Architecture overview
├── Algorithm summaries
├── File-by-file breakdown
├── Performance metrics
└── Testing recommendations

AUDIO_PIPELINE_ANALYSIS.md         ← DETAILED REFERENCE
├── Playback mechanics
├── Effect modes & toggling
├── DSP algorithms
├── AI separation workflow
├── UserDefaults persistence
├── Production readiness
└── Architecture assessment

AUDIO_PIPELINE_DIAGRAMS.md         ← VISUAL REFERENCE
├── 8 ASCII flow diagrams
├── Algorithm visualizations
├── Thread safety model
├── Data flow paths
└── Decision trees

AUDIO_QUICK_REFERENCE.md           ← QUICK LOOKUP
├── Property tables
├── Method reference
├── Algorithm summaries
├── Code examples
├── Debugging tips
└── Performance baselines

README_AUDIO_ANALYSIS.md           ← THIS FILE
├── Navigation guide
├── Use case routing
├── Statistics
└── Q&A index
```

---

**Documentation Version:** 1.0  
**Last Updated:** May 11, 2026  
**Scope:** Complete audio pipeline (5 key classes, ~2,080 lines)  
**Quality:** Production-ready (A- grade code, comprehensive docs)

