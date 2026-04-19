# Boxed Up — Development Journal

> This file tracks all development progress, decisions, and changes. Any AI agent contributing to this project should read this file first for full context, then update it after making changes.

---

## Project Summary

**Boxed Up** is a motion-controlled boxing reaction game using two Apple devices:
- **Apple Watch** — worn on the punching wrist, captures motion via CoreMotion at 50 Hz
- **iPhone** — acts as sparring partner display, runs ML classification, and scores responses

**Communication chain:** Watch (CoreMotion) → WCSession → iPhone (ML + display + score) → WCSession → Watch (haptic)

**Full plan:** See [plan.md](plan.md)

---

## Architecture Overview

- **Single Xcode project**, two targets: iOS ("Boxed Up") + watchOS ("Boxed Up Watch Watch App")
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` — files added to target folders are auto-discovered
- **Shared code** lives in a `Shared/` top-level folder (added to both targets via target membership in Xcode)
- **No Mac target**, no Multipeer Connectivity — only WatchConnectivity between Watch ↔ iPhone

### Folder Structure (Target)
```
Boxed Up/                              # iOS target root (auto-synced)
Boxed Up Watch Watch App/              # watchOS target root (auto-synced)
Shared/                                # Must be manually added to both targets in Xcode
```

### Key Frameworks
- `WatchConnectivity` — real-time Watch ↔ iPhone messaging
- `CoreMotion` — accelerometer + gyroscope on Watch (50 Hz)
- `CoreML` — punch classification on iPhone
- `HealthKit` — `HKWorkoutSession` to keep Watch app alive during gameplay

---

## Progress Log

### Entry 1 — April 13, 2026 — Project Initialization

**Status:** Starting Phase 1 (Foundation) + Phase 2 (WatchConnectivity)

**What exists:**
- iOS target ("Boxed Up") — template SwiftUI app with `Boxed_UpApp.swift` and `ContentView.swift`
- watchOS target ("Boxed Up Watch Watch App") — template SwiftUI app with `Boxed_Up_WatchApp.swift` and `ContentView.swift`
- Both targets have only default "Hello, world!" placeholder code
- iOS deployment target: 26.4, Bundle ID: `com.biru.Boxed-Up`
- watchOS target embedded in iOS app via "Embed Watch Content" build phase
- No shared code, no models, no networking, no ML — completely fresh

**What was built:**

#### Phase 1 — Shared Data Models (✅ Complete)
All files in `Shared/` at project root — must be manually added to both targets' membership in Xcode.

| File | Description |
|------|-------------|
| `Shared/Models/PunchType.swift` | Enum: `.jab`, `.hook`, `.uppercut` — Codable, CaseIterable |
| `Shared/Models/GameAction.swift` | 6 actions (3 attacks + 3 openings), with `isAttack` and `displayLabel` computed properties |
| `Shared/Models/PunchResult.swift` | Struct: punchType, confidence (0-1), reactionTime |
| `Shared/Models/MotionSample.swift` | Struct: timestamp + 6 channels (acc xyz, rot xyz) + `accelerationMagnitude` computed property |
| `Shared/Models/WatchMessage.swift` | Enum with `toDictionary()` and `from(_:)` for WCSession messaging. Handles: motionData, motionStarted/Stopped, startCapture/stopCapture, punchDetected, gameState, roundStart/End |
| `Shared/Models/Score.swift` | Struct with running totals, streak tracking, `recordPunch()` mutating method, computed accuracy/avgReactionTime/avgConfidence |
| `Shared/GameLogic/CounterMapping.swift` | Static mapping: attackJab→uppercut, attackHook→jab, attackUppercut→hook, openHead→jab, openBody→uppercut, openSide→hook |
| `Shared/GameLogic/ScoringEngine.swift` | Points = 100 × reactionMultiplier × confidence. Reaction tiers: 2.0× (<0.3s), 1.5× (<0.5s), 1.0× (<1.0s), 0.5× (≥1.0s). Streak bonus: streak×10 for streaks ≥3 |
| `Shared/GameLogic/RoundManager.swift` | @Observable class. Config: actionsPerRound, interval, difficulty (easy/normal/hard). Generates balanced random sequences (no 3+ consecutive same-type). Tracks currentAction, elapsedReactionTime |

#### Phase 2 — WatchConnectivity (✅ Complete)

| File | Description |
|------|-------------|
| `Boxed Up/WatchRelay/WatchSessionManager.swift` | `PhoneSessionManager` — iPhone-side WCSession delegate. @Observable. Tracks isWatchReachable, isSessionActivated. Callbacks: onMotionData, onMotionLifecycle. Implements iOS-required sessionDidBecomeInactive/sessionDidDeactivate |
| `Boxed Up/WatchRelay/MotionDataBuffer.swift` | Sliding window buffer (50 samples = 1 sec at 50 Hz). Punch detection via acceleration magnitude threshold (1.5g). captureWindow() returns latest 50 samples for ML |
| `Boxed Up Watch Watch App/MotionCapture/WatchMotionManager.swift` | Wraps CMMotionManager at 50 Hz. Captures userAcceleration + rotationRate. Callback-based via onSample |
| `Boxed Up Watch Watch App/MotionCapture/MotionStreamer.swift` | Batches 5 samples per WCSession message (~100ms between sends). flush() for remaining samples |
| `Boxed Up Watch Watch App/WatchSessionManager.swift` | `WatchSessionManager` — Watch-side WCSession delegate. @Observable. Callbacks: onGameState, onPunchDetected, onCaptureControl, onRoundLifecycle |

#### Phase 4 — iPhone Sparring UI (✅ Complete — placeholder ML)

| File | Description |
|------|-------------|
| `Boxed Up/ViewModels/SparringViewModel.swift` | Main game loop orchestrator. GamePhase: .home/.playing/.results. Wires motion buffer → punch detection → classification (TODO: Core ML) → scoring → Watch haptic feedback. Currently uses random classifier placeholder |
| `Boxed Up/Views/HomeView.swift` | Start screen with Watch connection status, "Start Round" button (disabled when Watch not connected) |
| `Boxed Up/Views/SparringView.swift` | Main game screen: action display (icon + label + color), score bar (accuracy, streak, points), punch feedback overlay (correct/wrong + reaction time + confidence) |
| `Boxed Up/Views/ResultsView.swift` | Post-round stats: score, accuracy, avg reaction time, best streak. Play Again + Home buttons |
| `Boxed Up/Boxed_UpApp.swift` | **Modified** — wires PhoneSessionManager + SparringViewModel, switches views based on gamePhase |

#### Phase 5 — Watch Game UI (✅ Complete)

| File | Description |
|------|-------------|
| `Boxed Up Watch Watch App/Views/WatchHomeView.swift` | Shows connection status to iPhone, "Ready" indicator |
| `Boxed Up Watch Watch App/Views/WatchGameView.swift` | Minimal: current action icon + label, correct/wrong indicator |
| `Boxed Up Watch Watch App/Boxed_Up_WatchApp.swift` | **Modified** — coordinates WatchSessionManager + WatchMotionManager + MotionStreamer. Handles capture start/stop, game state, haptic feedback via WKInterfaceDevice |

#### Files NOT modified (still template):
- `Boxed Up/ContentView.swift` — orphaned, no longer referenced by app entry point
- `Boxed Up Watch Watch App/ContentView.swift` — orphaned, no longer referenced

**⚠️ Required manual steps in Xcode:**
1. Add `Shared/` folder to the Xcode project (drag into navigator)
2. For every file in `Shared/`, check target membership for BOTH "Boxed Up" (iOS) AND "Boxed Up Watch Watch App" (watchOS) in the File Inspector
3. Add `WatchConnectivity.framework` to both targets (should auto-link from imports)
4. Add `CoreMotion.framework` to watchOS target
5. Add `NSMotionUsageDescription` to watchOS Info.plist
6. Optionally delete orphaned `ContentView.swift` files from both targets

**Known TODOs:**
- `SparringViewModel.classifyPunch()` — returns random punch type. Must replace with Core ML model (Phase 3)
- ~~Data collection mode not yet built (Phase 6)~~ ✅ Built
- No `HKWorkoutSession` integration yet — Watch app may suspend during long rounds
- No error handling for WCSession disconnects mid-round
- Timer-based action advancement not yet implemented (currently only advances after punch)

---

## Entry 2 — watchOS Build Fix (`.onAppear` on `WindowGroup`)

**Problem:**
Build error in `Boxed_Up_WatchApp.swift`:
> `value of type 'WindowGroup<_ConditionalContent<WatchGameView, WatchHomeView>>' has no member 'onAppear'`

**Root Cause:**
`.onAppear` is a `View` modifier, but `WindowGroup` is a `Scene`. Attaching `.onAppear` directly to `WindowGroup` is invalid.

**Fix:**
Wrapped the conditional view content inside a `Group` view and moved `.onAppear` onto the `Group` instead of the `WindowGroup`.

**File changed:**
- `Boxed Up Watch Watch App/Boxed_Up_WatchApp.swift`

**Result:**
Both targets (`Boxed Up` iOS and `Boxed Up Watch Watch App` watchOS) build successfully via `xcodebuild`.

---

## Entry 3 — Phase 6: Training Data Collection Mode + ML Model Plan

### What was built

Implemented the full data collection infrastructure for recording labeled punch training data from the Apple Watch.

#### New files created:

**Shared:**
- `Shared/Models/DataCollectionLabel.swift` — 4 labels: jab, hook, uppercut, other. Each has display name, description, SF Symbol icon.

**iPhone (iOS target):**
- `Boxed Up/ViewModels/DataCollectionViewModel.swift` — Recording lifecycle (countdown → capture → save), CSV persistence in labeled directories, consolidated CSV export, session count tracking, motion callback management.
- `Boxed Up/Views/DataCollectionView.swift` — Full data collection UI: segmented label picker, per-label session counters (color-coded: red < 20, orange < 50, green ≥ 50), record button with 3-2-1 countdown and recording indicator, export via share sheet, delete all with confirmation, Watch connection status. Includes `ShareSheet` UIKit wrapper.

**watchOS target:**
- `Boxed Up Watch Watch App/Views/WatchDataCollectionView.swift` — Minimal Watch display showing "Data Collection" mode indicator, recording status with haptic feedback on start/stop.

#### Files modified:

- `Shared/Models/WatchMessage.swift` — Added `.enterDataCollection` and `.exitDataCollection` message types (iPhone → Watch) for switching the Watch into data collection mode.
- `Boxed Up Watch Watch App/WatchSessionManager.swift` — Added `onDataCollectionMode: ((Bool) -> Void)?` callback, routes new message types.
- `Boxed Up Watch Watch App/Boxed_Up_WatchApp.swift` — Replaced `isRoundActive: Bool` with `WatchAppMode` enum (`.home`, `.game`, `.dataCollection`). Watch now shows `WatchDataCollectionView` when in data collection mode. Added haptic feedback (`.start`/`.stop`) during data collection recording.
- `Boxed Up/Boxed_UpApp.swift` — Added `DataCollectionViewModel` state and `isDataCollectionMode` flag. Routes to `DataCollectionView` when active. `enterDataCollection()` creates the view model and notifies Watch; `exitDataCollection()` restores `SparringViewModel`'s motion callback.
- `Boxed Up/Views/HomeView.swift` — Added `onCollectData: () -> Void` parameter. New "Collect Training Data" button below "Start Round".
- `Boxed Up/ViewModels/SparringViewModel.swift` — Changed `setupMotionCallback()` from `private` to `func` so the app entry point can restore it after data collection.

### Data flow

1. iPhone HomeView → "Collect Training Data" → sends `.enterDataCollection` to Watch
2. Watch switches to `WatchDataCollectionView`
3. iPhone: user selects label, taps Record → 3-2-1 countdown
4. iPhone sends `.startCapture` → Watch starts CoreMotion, streams `.motionData` back
5. After 3 seconds: iPhone sends `.stopCapture` → Watch stops, plays haptic
6. iPhone saves buffered samples as CSV in `Documents/TrainingData/{label}/session_*.csv`
7. Repeat for more samples
8. iPhone "Done" → sends `.exitDataCollection` → both return to home

### Data format

Individual session CSVs (per recording):
```
timestamp,accX,accY,accZ,rotX,rotY,rotZ
```
- Compatible with `MLActivityClassifier.DataSource.labeledDirectories(at:)`

Consolidated export CSV (for sharing):
```
sessionId,label,timestamp,accX,accY,accZ,rotX,rotY,rotZ
```
- Compatible with `MLDataTable` / `DataFrame` workflows

### ML Model Architecture (added to plan.md)

Three models planned for the game:

1. **Punch Type Classifier** (Critical) — 3-class Activity Classifier (jab/hook/uppercut), 50-sample window (1.0s), replaces the `classifyPunch()` random placeholder.
2. **Punch Detector** (Recommended) — Binary Activity Classifier (punch/other), 25-sample window (0.5s), replaces the crude 1.5g threshold. Smaller window gives faster detection and more precise reaction timing.
3. **Punch Quality Estimator** (Future/Optional) — Tabular Regressor on aggregated features for enhanced scoring.

Two-stage runtime pipeline: Detector triggers on punch → Classifier identifies type → Scoring Engine evaluates.

### Data collection targets

| Label | Min | Recommended | Purpose |
|-------|-----|-------------|---------|
| Jab | 50 | 100+ | Classifier + detector positive |
| Hook | 50 | 100+ | Classifier + detector positive |
| Uppercut | 50 | 100+ | Classifier + detector positive |
| Other | 50 | 100+ | Detector negative class |

### Build result

Both targets (`Boxed Up` iOS and `Boxed Up Watch Watch App` watchOS) build successfully via `xcodebuild`.

### Remaining TODOs

- Phase 3: Integrate actual Core ML models (after training data is collected)
- ~~`HKWorkoutSession` for Watch keep-alive~~ ✅ Built
- Timer-based action advancement
- ~~WCSession disconnect handling~~ ✅ Built

---

## Entry 4 — HKWorkoutSession + WCSession Disconnect Handling

### What was built

Two reliability features implemented in parallel with Phase 6:

#### 1. HKWorkoutSession (Watch keep-alive)

**Problem:** watchOS suspends apps after a few seconds of inactivity. During gameplay or data collection, the Watch app would lose the ability to capture motion.

**Solution:** Created `WorkoutSessionManager` that wraps `HKWorkoutSession` with `.boxing` activity type. Session starts/ends automatically with round lifecycle and data collection mode.

**New file:**
- `Boxed Up Watch Watch App/WorkoutSessionManager.swift` — `@Observable` class wrapping `HKHealthStore`, `HKWorkoutSession`, and `HKLiveWorkoutBuilder`. Handles authorization, session start/end, and workout builder lifecycle. Implements both `HKWorkoutSessionDelegate` and `HKLiveWorkoutBuilderDelegate`.

**Wiring in `Boxed_Up_WatchApp.swift`:**
- `workoutManager.requestAuthorization()` called during setup
- `workoutManager.startSession()` on round start and entering data collection mode
- `workoutManager.endSession()` on round end and exiting data collection mode

**Note:** Requires HealthKit capability to be enabled in Xcode for the watchOS target.

#### 2. WCSession disconnect handling (game pause/resume)

**Problem:** If the Watch disconnects mid-round (out of range, Watch app backgrounded), the game would silently break — no motion data arrives, no feedback is sent.

**Solution:** Added reachability change callbacks on both sides with automatic pause/resume.

**iPhone side (PhoneSessionManager + SparringViewModel):**
- `PhoneSessionManager.onReachabilityChanged` callback fires on Watch reachability changes
- `SparringViewModel` tracks `isDisconnected` state
- On disconnect during `.playing`: pauses reaction timer (`RoundManager.pauseReactionTimer()`), stops waiting for punches
- On reconnect: resets motion buffer, re-sends current game state to Watch (`roundStart` + `startCapture` + `gameState`), resumes timer preserving elapsed time
- `SparringView` shows a full-screen "Watch Disconnected" overlay with activity indicator and "End Round" escape button

**Watch side (WatchSessionManager + Boxed_Up_WatchApp):**
- `WatchSessionManager.onReachabilityChanged` callback fires on iPhone reachability changes
- On iPhone disconnect: stops motion capture (conserves battery), plays `.failure` haptic

**RoundManager changes:**
- Added `pausedElapsed: TimeInterval?` property
- `pauseReactionTimer()` — captures elapsed time and nils out `actionStartTime`
- `resumeReactionTimer()` — restores `actionStartTime` offset by previously elapsed time so scoring isn't penalized by disconnect duration

### Files modified

| File | Changes |
|------|---------|
| `Boxed Up Watch Watch App/Boxed_Up_WatchApp.swift` | Added `workoutManager`, wired HKWorkoutSession lifecycle + disconnect handling |
| `Boxed Up Watch Watch App/WatchSessionManager.swift` | Added `onReachabilityChanged` callback, fires in `sessionReachabilityDidChange` |
| `Boxed Up/WatchRelay/WatchSessionManager.swift` | Added `onReachabilityChanged` callback, fires in `sessionReachabilityDidChange` |
| `Boxed Up/ViewModels/SparringViewModel.swift` | Added `isDisconnected` state, `setupDisconnectHandling()`, `pauseForDisconnect()`, `resumeAfterReconnect()` |
| `Boxed Up/Views/SparringView.swift` | Added disconnect overlay with reconnection UI |
| `Shared/GameLogic/RoundManager.swift` | Added `pausedElapsed`, `pauseReactionTimer()`, `resumeReactionTimer()` |

### New file

- `Boxed Up Watch Watch App/WorkoutSessionManager.swift`

### Build result

Both targets build successfully via `xcodebuild`.

### Required Xcode manual steps

- Enable **HealthKit** capability on the watchOS target (Signing & Capabilities)
- Add `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` to watchOS Info.plist

---

## Entry 5 — Phase 3: ML Model Training + Core ML Integration

### Overview

Trained two Core ML models from 200 collected sessions (50 per label: jab, hook, uppercut, other) and integrated them into the iOS target, replacing the random placeholder classifier with a two-stage ML pipeline.

### Training

Created `TrainModels.swift` — a self-contained Swift script that:
1. Parses the consolidated `BoxedUp_TrainingData.csv` (28,830 rows across 200 sessions)
2. Splits into per-label directories for `MLActivityClassifier.DataSource.labeledDirectories(at:)`
3. Trains **PunchClassifier** (3-class: jab/hook/uppercut, window=50) from 150 punch-only sessions
4. Trains **PunchDetector** (2-class: punch/other, window=25) from all 200 sessions (jab+hook+uppercut merged into "punch")
5. Outputs both `.mlmodel` files to `MLModels/`

**No separate Create ML project needed** — the script runs directly via `swift TrainModels.swift BoxedUp_TrainingData.csv`.

### Training results

| Model | Training Error | Validation Error | Window Size |
|-------|---------------|-----------------|-------------|
| PunchClassifier | 4.9% | 50% | 50 (1.0s) |
| PunchDetector | 1.7% | 29.5% | 25 (0.5s) |

Validation error will improve with more training data (currently at minimum 50 sessions/label). The model is functional but benefits from 100+ sessions per label.

### New files

| File | Purpose |
|------|---------|
| `TrainModels.swift` | Swift training script (run on macOS, no Xcode project needed) |
| `MLModels/PunchClassifier.mlmodel` | 3-class punch type classifier (1.0 MB) |
| `MLModels/PunchDetector.mlmodel` | Binary punch detector (0.97 MB) |
| `Boxed Up/MLClassifier/PunchClassifierService.swift` | Core ML wrapper — two-stage pipeline (detect → classify) |

### `PunchClassifierService` design

- Wraps both models behind a single service class
- `detectPunch(from:)` — Stage 1: binary detection via PunchDetector (25-sample window), returns `(isPunch: Bool, confidence: Double)`
- `classifyPunch(from:)` — Stage 2: type classification via PunchClassifier (50-sample window), returns `(punchType: PunchType, confidence: Double)`
- Manages `stateIn`/`stateOut` recurrent state for both models (Activity Classifier uses LSTM)
- `resetState()` — clears recurrent state between rounds
- Builds `MLDictionaryFeatureProvider` with 6 feature arrays + state for each prediction
- Graceful nil init if model files missing from bundle (fallback to random)

### SparringViewModel changes

- Added `classifier: PunchClassifierService?` dependency
- `startRound()` calls `classifier?.resetState()`
- `setupMotionCallback()` now uses two-stage pipeline:
  - If ML models loaded: detector checks each batch (`confidence > 0.6` threshold) → on detection, classifier identifies type
  - If models missing: falls back to 1.5g acceleration threshold
- `classifyPunch(from:)` delegates to `classifier.classifyPunch()` or falls back to random

### MotionDataBuffer change

- Added `allSamples` computed property for detector access to the full buffer

### Two-stage runtime pipeline

```
Motion samples → MotionDataBuffer
                    │
                    ▼
              PunchDetector (25 samples)
              "Is this a punch?"
                    │ confidence > 0.6
                    ▼
              PunchClassifier (50 samples)
              "What type of punch?"
                    │
                    ▼
              ScoringEngine → UI → Watch haptic
```

### Build result

Both targets build successfully via `xcodebuild`.

### Required Xcode manual steps

- Drag `MLModels/PunchClassifier.mlmodel` and `MLModels/PunchDetector.mlmodel` into the iOS target in Xcode
- Ensure both models have target membership in "Boxed Up" (iOS) only
- Add `PunchClassifierService.swift` to the iOS target membership

### To retrain models

Collect more training data → export CSV → run:
```bash
swift TrainModels.swift BoxedUp_TrainingData.csv
```
Then replace the `.mlmodel` files in Xcode.

### Remaining TODOs

- ~~Timer-based action advancement (actions only advance after punch, no timeout)~~ ✅ Implemented
- More training data for better accuracy (100+ sessions per label recommended)
- ~~Phase 7: full integration & polish~~ ✅ Complete

---

## Entry 6 — Phase 7: Integration & Polish (Final Phase)

### Overview

Completed Phase 7 — the final phase of the project. All game loop edge cases, polish features, and optimizations are now implemented. The entire end-to-end flow works: iPhone shows action → Watch captures punch → iPhone classifies via ML → scores → Watch haptic feedback.

### What was built

#### 1. Timer-based Action Timeout (Critical)

**Problem:** If the player didn't throw a punch, the game would hang indefinitely on the current action.

**Solution:** Added `startReactionTimeout()` in `SparringViewModel` that starts a countdown task for each action. Uses `config.effectiveReactionWindow` (difficulty-adjusted) as the timeout duration. Updates `reactionTimeRemaining` (0.0–1.0 fraction) at 20fps for smooth UI countdown.

When the timer expires, `handleTimeout()`:
- Records a miss (0 points, breaks streak, false accuracy)
- Shows "TOO SLOW!" feedback in the UI
- Plays a timeout sound effect
- Auto-advances to the next action after 0.8s delay

Timer is cancelled on successful punch detection, paused on Watch disconnect, and resumed on reconnect.

#### 2. Reaction Timer Bar UI

Added a color-coded countdown bar below the action display in `SparringView`:
- Green (>50% remaining) → Yellow (25-50%) → Red (<25%)
- Smooth animation via `.linear(duration: 0.05)` matching the 20fps tick rate
- Uses `GeometryReader` for proper width scaling

#### 3. Timeout Miss UI

Added a dedicated "TOO SLOW!" state in `SparringView`:
- Shows `clock.badge.xmark` icon in orange with "TOO SLOW!" text
- Triggers when `lastPunchCorrect == false && lastPunchResult == nil` (miss vs wrong punch)

#### 4. Debug Hint Removed

Removed the debug text that showed the correct answer (`"Throw: JAB"`) from `SparringView`. Players must now figure out the correct counter punch based on the displayed action.

#### 5. Sound Effects on iPhone

Created `SoundManager` (`Boxed Up/Audio/SoundManager.swift`) using `AudioToolbox.AudioServicesPlaySystemSound` for lightweight, low-latency sound feedback:

| Event | System Sound ID | Description |
|-------|----------------|-------------|
| Punch detected | 1104 (Tock) | Immediate feedback on punch detection |
| Correct punch | 1025 (New Mail) | Positive chime |
| Wrong punch | 1073 (VC Ended) | Negative sound |
| Timeout miss | 1053 (Tweet Sent) | Miss indicator |
| Round complete | 1026 (Sent Mail) | Completion sound |

Integrated into `SparringViewModel.processPunch()`, `handleTimeout()`, and `endRound()`.

#### 6. Idle Timer Disabled During Gameplay

Added `UIApplication.shared.isIdleTimerDisabled = true` on `SparringView.onAppear` and restored to `false` on `.onDisappear`. Prevents the iPhone screen from dimming/locking during active gameplay when placed on a stand.

#### 7. ML Inference Off Main Thread

Moved CoreML two-stage pipeline (PunchDetector + PunchClassifier) to a dedicated `DispatchQueue` (`com.boxedup.ml`, `.userInitiated` QoS):
- Motion data still arrives and is buffered on MainActor
- ML detection runs on background queue
- On punch detection, hops back to MainActor for `processPunch()`
- Keeps UI responsive during inference (~15-25ms per prediction)

#### 8. Stale TODO Comment Cleanup

Removed outdated `// TODO: Replace with actual Core ML classification (Phase 3)` comment from `processPunch()` — ML models have been integrated since Entry 5.

### Files created

| File | Purpose |
|------|---------|
| `Boxed Up/Audio/SoundManager.swift` | System sound effects for game events |

### Files modified

| File | Changes |
|------|---------|
| `Boxed Up/ViewModels/SparringViewModel.swift` | Added `reactionTimeRemaining`, `timeoutTask`, `mlQueue`. New methods: `startReactionTimeout()`, `handleTimeout()`. Timeout integration in `startRound()`, `endRound()`, `processPunch()`, `advanceAction()`, `pauseForDisconnect()`, `resumeAfterReconnect()`. ML inference moved to background queue. Sound effects wired in. Removed stale TODO. |
| `Boxed Up/Views/SparringView.swift` | Added timer countdown bar with color grades. Added "TOO SLOW!" timeout feedback. Removed debug hint. Added idle timer disable. Imported UIKit. |

### Build result

Both targets (`Boxed Up` iOS and `Boxed Up Watch Watch App` watchOS) build successfully via `xcodebuild`.

### Project completion status

All 7 phases are now complete:
- ✅ Phase 1: Foundation (Shared models + game logic)
- ✅ Phase 2: WatchConnectivity (Real-time messaging)
- ✅ Phase 3: ML Pipeline (Two-stage detector + classifier)
- ✅ Phase 4: iPhone Sparring UI
- ✅ Phase 5: Watch Game UI
- ✅ Phase 6: Data Collection Mode
- ✅ Phase 7: Integration & Polish

### Remaining improvements (future)

- Collect more training data (100+ sessions per label) for better ML accuracy
- Train Punch Quality Estimator (Model 3 — tabular regressor for form scoring)
- Add difficulty selection UI in HomeView
- Add round/session history persistence
- Watch battery level surfaced in iPhone UI

---

## Entry 7 — Bug Fix: False Punch Re-detection After First Detection

### Problem

After the first punch was detected in a round, every subsequent action would immediately register a punch without the player actually throwing one — making the game unplayable.

### Root Cause (two-fold)

1. **Detector LSTM state carryover:** The PunchDetector uses an LSTM recurrent network. After detecting a punch, its hidden state (`detectorState`) retained the "punch" pattern. When new motion samples arrived for the next action, the detector's biased state immediately classified even idle/recovery motion as another punch.

2. **Stale motion data in buffer:** `advanceAction()` called `motionBuffer.clearOldSamples()` which only trimmed the buffer to the last 50 samples — still containing the previous punch's motion data. The detector (25-sample window) would see this leftover punch motion and fire instantly.

### Fix

1. **Added `resetDetectorState()`** to `PunchClassifierService` — resets only the detector's LSTM hidden state to zeros. Unlike `resetState()` (which resets both models between rounds), this targets just the detector between actions so the classifier's LSTM context is preserved.

2. **Full buffer reset between actions** — Changed `advanceAction()` to call `motionBuffer.reset()` (complete clear) instead of `motionBuffer.clearOldSamples()` (partial trim). The detector now starts each action with a clean buffer.

Both fixes are called in `advanceAction()` before the next action begins.

### Files modified

| File | Changes |
|------|---------|
| `Boxed Up/MLClassifier/PunchClassifierService.swift` | Added `resetDetectorState()` method |
| `Boxed Up/ViewModels/SparringViewModel.swift` | `advanceAction()`: replaced `clearOldSamples()` with `reset()` + `resetDetectorState()` |

### Build result

iOS target builds successfully.

---

## Entry 8 — ML Architecture Change: CreateML Activity Classifier → CNN 1D

**Branch:** `feature/cnn-models`

### Problem

The CreateML `MLActivityClassifier` models (LSTM-based) suffered from two issues:
1. **Overfitting** — The Activity Classifier architecture overfitted on the limited training data (50 sessions/label). Validation error was 50% for the classifier and 29.5% for the detector.
2. **LSTM state carryover** — The recurrent hidden state caused false re-detections between actions (fixed in Entry 7 with state resets, but was a fundamental architecture problem).

### Solution

Retrained both models using **1D Convolutional Neural Networks (CNN 1D)** via PyTorch → CoreML conversion (coremltools). CNN 1D generalizes better on small motion datasets because:
- Stateless — no recurrent hidden state to manage or leak between predictions
- Translation-invariant — learns local temporal patterns (punch signatures) regardless of position in the window
- Less prone to overfitting with limited data than LSTMs

### New models

| Model | File | Input | Output | Architecture |
|-------|------|-------|--------|-------------|
| PunchClassifier_CNN | `MLModels/PunchClassifier_CNN.mlmodel` | `motionData` Float32 [1, 6, 50] | `classLabel` (jab/hook/uppercut) + `var_84` probabilities | 3× Conv1D + ReLU + GlobalAvgPool + FC |
| PunchDetector_CNN | `MLModels/PunchDetector_CNN.mlmodel` | `motionData` Float32 [1, 6, 25] | `classLabel` (punch/other) + `var_83` probabilities | 3× Conv1D + ReLU + GlobalAvgPool + FC |

**Key differences from old models:**

| Aspect | Old (CreateML Activity Classifier) | New (CNN 1D) |
|--------|-----------------------------------|-------------|
| Architecture | LSTM (recurrent) | Conv1D (stateless) |
| Input format | 6 separate MLMultiArrays + stateIn | Single [1, 6, windowSize] tensor |
| Output names | `label`, `labelProbability`, `stateOut` | `classLabel`, `var_84`/`var_83` |
| State management | Requires manual LSTM state passing + reset | None needed |
| Data type | Float64 (Double) | Float32 |
| Framework | CreateML native | PyTorch → coremltools conversion |
| Overfitting risk | High (LSTM on small data) | Lower (CNN generalizes better) |

### Changes to `PunchClassifierService.swift`

Complete rewrite of the service to accommodate the CNN architecture:

1. **Removed all LSTM state management** — No more `classifierState`, `detectorState`, `stateSize` properties
2. **Simplified init** — Loads `PunchClassifier_CNN.mlmodelc` and `PunchDetector_CNN.mlmodelc` (no state arrays to allocate)
3. **New `buildCNNInput()` method** — Packs 6-channel motion data into a single `[1, 6, windowSize]` Float32 MLMultiArray using 3D indexed access (`motionData[[0, channel, timeStep]]`)
4. **Updated output parsing** — Reads `classLabel` instead of `label`, reads `var_84`/`var_83` instead of `labelProbability`
5. **`resetState()` and `resetDetectorState()` are now no-ops** — Kept for API compatibility with `SparringViewModel` calls, but CNN models have no state to reset

### Files modified

| File | Changes |
|------|---------|
| `Boxed Up/MLClassifier/PunchClassifierService.swift` | Full rewrite: removed LSTM state, single-tensor CNN input, updated output names |

### Files unchanged (API stable)

- `SparringViewModel.swift` — No changes needed. Calls to `resetState()` and `resetDetectorState()` still work (no-ops). The `detectPunch(from:)` and `classifyPunch(from:)` APIs are unchanged.

### New model files

| File | Size | Source |
|------|------|--------|
| `MLModels/PunchClassifier_CNN.mlmodel` | — | PyTorch Conv1D → coremltools |
| `MLModels/PunchDetector_CNN.mlmodel` | — | PyTorch Conv1D → coremltools |

### Build result

Both targets (iOS and watchOS) build successfully.

### Xcode manual steps

- Drag `MLModels/PunchClassifier_CNN.mlmodel` and `MLModels/PunchDetector_CNN.mlmodel` into the iOS target in Xcode
- Ensure both have target membership in "Boxed Up" (iOS) only
- The old `PunchClassifier.mlmodel` and `PunchDetector.mlmodel` can be removed from the iOS target (kept in repo for reference on main branch)

---

## Entry 9 — Simplified Game Mechanic & Difficulty Selection UI

### Problem

The original game mechanic required the player to interpret an attack or opening and then mentally map it to the correct counter punch (e.g., "ATTACK — JAB" means throw an uppercut). This counter-mapping added cognitive overhead that detracted from the core physical reaction experience.

### Solution: Direct Punch Display

Changed the game to display the punch type directly: the screen now shows "JAB", "HOOK", or "UPPERCUT" and the player simply throws that exact punch. This eliminates the `GameAction` → `CounterMapping` → `PunchType` indirection.

**Before:** Display `GameAction` (6 types: 3 attacks + 3 openings) → Player figures out correct counter → `CounterMapping.isCorrect(punch:for:)` checks answer

**After:** Display `PunchType` directly (JAB/HOOK/UPPERCUT) → Player throws that punch → Direct comparison (`thrownPunch == expectedPunch`)

### Changes

#### `Shared/GameLogic/RoundManager.swift`
- Changed `actions: [GameAction]` → `actions: [PunchType]`
- Changed `currentAction: GameAction?` → `currentAction: PunchType?`
- Updated `generateActionSequence()` to pick from `PunchType.allCases`
- Updated `wouldCreateBadRun()` to prevent 3+ consecutive same punch type (was previously checking attack/opening category)

#### `Shared/Models/WatchMessage.swift`
- Changed `.gameState(GameAction)` → `.gameState(PunchType)`
- Updated encode/decode to serialize `PunchType.rawValue` instead of `GameAction.rawValue`

#### `Boxed Up/ViewModels/SparringViewModel.swift`
- Replaced `CounterMapping.isCorrect(punch:for:)` with direct comparison: `classifiedPunch.punchType == expectedPunch`
- Updated all `.gameState()` sends to pass `PunchType` from `roundManager.currentAction`

#### `Boxed Up/Views/SparringView.swift`
- Replaced attack/opening display (red/green with shield/scope icons) with a single boxing icon and punch type label
- Shows `punch.rawValue.uppercased()` (e.g., "JAB") in bold red

#### `Boxed Up Watch Watch App/Views/WatchGameView.swift`
- Updated to accept `PunchType?` instead of `GameAction?`
- Simplified display to show punch type directly with boxing icon

#### `Boxed Up Watch Watch App/WatchSessionManager.swift`
- Changed `onGameState` callback type from `((GameAction) -> Void)?` to `((PunchType) -> Void)?`

#### `Boxed Up Watch Watch App/Boxed_Up_WatchApp.swift`
- Changed `currentAction` state from `GameAction?` to `PunchType?`

### Files now unused

| File | Status |
|------|--------|
| `Shared/Models/GameAction.swift` | No longer referenced by game flow. Can be removed. |
| `Shared/GameLogic/CounterMapping.swift` | No longer referenced. Can be removed. |

### Solution: Difficulty Selection UI

Added a segmented `Picker` to `HomeView` allowing the player to choose Easy, Normal, or Hard difficulty before starting a round.

#### `Boxed Up/Views/HomeView.swift`
- Added a "Difficulty" label with a segmented `Picker` bound to `viewModel.roundManager.config.difficulty`
- Picker uses `RoundManager.Config.Difficulty.allCases` to populate options
- Placed between the Watch connection status and the Start Round button

The existing `RoundManager.Config.Difficulty` enum already had the multipliers:
- **Easy:** 1.3× interval, 1.3× reaction window (slower, more forgiving)
- **Normal:** 1.0× (default)
- **Hard:** 0.7× interval, 0.7× reaction window (faster, less forgiving)

### Build result

Both targets (iOS and watchOS) build successfully.

### Post-build fix: `roundManager` binding error

The difficulty `Picker` in `HomeView` creates a binding via `$viewModel.roundManager.config.difficulty`. This requires a writable key path through the `@Observable` class. `roundManager` was declared as `let` in `SparringViewModel`, which makes the property read-only and prevents SwiftUI from creating a `Binding` through it.

**Fix:** Changed `let roundManager = RoundManager()` to `var roundManager = RoundManager()` in `SparringViewModel.swift`. With the `@Observable` macro, `var` properties get synthesized get/set accessors that enable `@Bindable` to produce writable bindings.

### Updated `plan.md`

Updated the project plan to reflect the current architecture:
- Removed `GameAction.swift` and `CounterMapping.swift` from the folder structure and data model sections
- Updated `WatchMessage` to show `.gameState(PunchType)` instead of `.gameState(GameAction)`
- Updated `SparringView` description to show direct punch type display
- Updated `SparringViewModel` game flow to reflect direct comparison, two-stage ML pipeline, timeout/disconnect handling, sound effects
- Updated `HomeView` description to include difficulty picker
- Updated `WatchGameView` description to show punch type display

---

## Entry 10 — Phase 8 Planning: DIY Smart Glove (ESP32 + MPU6050)

### Motivation

The Apple Watch only tracks one hand. To enable dual-hand features like punching combos (e.g., L-JAB → R-HOOK → L-UPPERCUT), the other hand needs a motion sensor too. Solution: a DIY smart glove built with student-accessible IoT components that streams the same 6-axis IMU data to the iPhone over BLE.

### Hardware Design

**Components (~$15–25 USD total):**

| Component | Model | Purpose |
|-----------|-------|---------|
| Microcontroller | ESP32-WROOM-32 DevKit V1 (30-pin) | BLE communication + IMU host. ~$5–8. |
| IMU sensor | MPU6050 (GY-521 breakout) | 6-axis accelerometer + gyroscope. Matches Watch's 6 channels. ~$2–3. |
| Battery | 3.7V LiPo 500mAh | ~2–3 hours runtime. Rechargeable. ~$3–5. |
| Charger | TP4056 USB-C module | Charges LiPo with overcurrent/overdischarge protection. ~$1–2. |
| Switch | SPDT slide switch | Power on/off. ~$0.50. |
| Glove | Fingerless workout glove | Mount electronics on back of wrist. ~$3–5. |
| Mounting | Velcro strips + zip ties | Secure and removable for charging. ~$1–2. |

**Wiring (6 connections):**
- MPU6050 VCC → ESP32 3V3, GND → GND, SDA → GPIO21, SCL → GPIO22, INT → GPIO19, AD0 → GND
- Power: LiPo → TP4056 (charge + protect) → slide switch → ESP32 VIN

### Firmware

Arduino IDE sketch on ESP32:
- Initializes MPU6050 at ±8g accel / ±1000°/s gyro with 42 Hz low-pass filter
- Calibrates at boot (averages 100 rest samples, subtracts bias offsets)
- BLE peripheral advertising as `"BoxedUpGlove"` with custom GATT service
- Notify characteristic streams 5-sample batches at 50 Hz (140 bytes per notification)
- Control characteristic accepts write commands to start/stop capture
- Binary packet format per sample: `[timestamp_ms(4) + accXYZ(12) + rotXYZ(12)]` = 28 bytes Float32

### iPhone Integration Plan

- New `GloveSessionManager` using CoreBluetooth (mirrors `PhoneSessionManager` API)
- Scans for `"BoxedUpGlove"`, connects, subscribes to motion notifications
- Parses binary packets into existing `MotionSample` structs
- Separate `MotionDataBuffer` for left hand
- Same CNN ML pipeline applied to left-hand data (separate trained models)
- `Info.plist` needs `NSBluetoothAlwaysUsageDescription`

### New Game Mode: Combo

Dual-hand tracking enables combo sequences:
- Display: `L-JAB → R-HOOK → L-UPPERCUT` (hand + punch type sequence)
- Player executes in order, each punch validated independently
- Combo scoring: all-correct bonus + rhythm bonus + speed bonus
- New models: `HandSide` enum, `ComboAction` struct, `ComboManager` class
- HomeView gains game mode picker: Single Hand / Combo

### Updated plan.md

Added comprehensive Phase 8 to `plan.md`:
- Section 8.1: Full component list with prices and sourcing
- Section 8.2: Detailed wiring diagram (ASCII) with pin-by-pin table
- Section 8.3: Step-by-step assembly (breadboard → perfboard → glove mount) with layout diagram
- Section 8.4: Complete ESP32 Arduino firmware sketch with BLE GATT, MPU6050 reading, calibration, batched notify
- Section 8.5: iPhone CoreBluetooth architecture diagram, new files, binary packet parsing code
- Section 8.6: Dual-hand data collection extension
- Section 8.7: Dual-hand ML strategy (separate models per hand vs unified 12-channel)
- Section 8.8: Combo game mode design (sequences, scoring, UI, new types)
- Section 8.9: Latency budget (~25–50ms glove path)
- Section 8.10: Info.plist BLE permissions
- Section 8.11: Calibration & axis alignment guide
- Updated dependency graph, key decisions table, verification plan (6 new steps), and risks table (8 new risks)

## Entry 11 — Phase 8.5: Smart Glove BLE Integration & Motion Sensor Testing

**Date:** 2025-04-13  
**Phase:** 8 — DIY Smart Glove (BLE Testing)

### Context

ESP32 + MPU6050 hardware was assembled on breadboard and firmware uploaded. BLE connectivity was verified successfully using nRF Connect app — the `BoxedUpGlove` peripheral advertises, connects, and its GATT service/characteristics are visible. Next step: test the actual MPU6050 motion data streaming through the iPhone app before committing to soldering on a permanent board.

### What Was Done

1. **Created `BLERelay/GloveConstants.swift`** — Centralized BLE UUID definitions and binary packet format constants matching the ESP32 firmware (`BoxedUp.ino`). Service UUID, motion/control characteristic UUIDs, bytes-per-sample (28), batch size (5), start/stop command bytes.

2. **Created `BLERelay/GloveSessionManager.swift`** — Full CoreBluetooth `CBCentralManager` + `CBPeripheralDelegate` implementation:
   - Scans for `BoxedUpGlove` service UUID
   - Auto-connects on discovery, subscribes to motion notify characteristic
   - Parses 140-byte binary BLE packets into `[MotionSample]` arrays (little-endian Float32)
   - `startCapture()` / `stopCapture()` write control commands to the ESP32
   - Auto-reconnect on disconnect
   - `@Observable` with `isGloveConnected`, `isScanning`, `onMotionData` callback
   - Mirrors the `PhoneSessionManager` API pattern for consistency

3. **Created `Views/GloveTestView.swift`** — Dedicated debug/test view for verifying sensor data:
   - Connection section: Scan button with progress indicator, connection status
   - Capture control: Start/Stop streaming toggle
   - Live IMU data: Real-time 6-axis display (acc X/Y/Z in g, gyro X/Y/Z in °/s), acceleration magnitude with threshold coloring (>1.5g turns red)
   - Stream stats: Total samples, sample rate (Hz), batch count, streaming status
   - Clean lifecycle: stops capture and scanning on dismiss

4. **Wired into app navigation:**
   - `Boxed_UpApp.swift`: Added `isGloveTestMode` state, routes to `GloveTestView` when active
   - `HomeView.swift`: Added "Test Smart Glove" button (orange, with hand icon) alongside existing "Collect Training Data" button

5. **Added BLE permission** — `NSBluetoothAlwaysUsageDescription` added to both Debug and Release build settings in `project.pbxproj` for the iOS target.

### New Files

| File | Purpose |
|------|---------|
| `Boxed Up/BLERelay/GloveConstants.swift` | BLE UUIDs, packet format constants |
| `Boxed Up/BLERelay/GloveSessionManager.swift` | CoreBluetooth BLE manager for ESP32 glove |
| `Boxed Up/Views/GloveTestView.swift` | Debug UI for testing motion sensor data |

### Modified Files

| File | Change |
|------|--------|
| `Boxed_UpApp.swift` | Added `isGloveTestMode` state and `GloveTestView` routing |
| `Views/HomeView.swift` | Added `onTestGlove` callback and "Test Smart Glove" button |
| `project.pbxproj` | Added `NSBluetoothAlwaysUsageDescription` to iOS target |

### Testing Plan

1. Build and run on physical iPhone (BLE requires real device, not simulator)
2. Power on ESP32 breadboard setup
3. Open app → tap "Test Smart Glove" → tap "Scan for Glove"
4. Verify connection established (green indicator)
5. Tap "Start Capture" → verify sample rate shows ~50 Hz
6. Move the MPU6050 sensor — verify live acc/gyro values change responsively
7. Throw test punches — verify acceleration magnitude spikes above 1.5g threshold
8. Tap "Stop Capture" → verify streaming stops cleanly
9. If data looks good → proceed with soldering to permanent board

### Key Decisions

- **Separate test view** rather than integrating into existing DataCollectionView — keeps glove testing isolated and simple for hardware debugging
- **`@State var gloveManager`** created locally in GloveTestView — lifecycle tied to the view. Will be elevated to app-level when integrating into the game flow later
- **Auto-reconnect on disconnect** — important for breadboard testing where connections may be flaky
- **Binary packet parsing** uses safe `Data` slicing with `withUnsafeBytes` + `loadUnaligned` — handles potential alignment issues

## Entry 12 — MPU6050 Sensor Diagnostic Tool

**Date:** 2025-04-19  
**Phase:** 8 — DIY Smart Glove (Hardware Debug)

### Problem

After uploading the main `BoxedUp.ino` firmware and testing BLE from the iPhone app, the motion sensor produced no data. BLE connects successfully (confirmed via nRF Connect in Entry 10), but the MPU6050 IMU may be improperly wired or defective. Need a way to isolate whether the issue is wiring, sensor, or firmware.

### What Was Done

Created `ESPFirmware/SensorDiagnostic.ino` — a standalone diagnostic sketch that runs 7 progressive hardware tests via Serial Monitor (115200 baud). No BLE, no library dependencies beyond `Wire.h`.

### Diagnostic Tests

| Test | What It Checks | Failure Means |
|------|---------------|---------------|
| 1. I2C Bus Init | Wire.begin on GPIO21/22 | Pins misconfigured |
| 2. I2C Bus Scan | Scans all 127 addresses | No device = wiring problem (VCC/GND/SDA/SCL) |
| 3. WHO_AM_I | Reads register 0x75, expects 0x68 | Wrong device or dead sensor |
| 4. Power Management | Checks sleep bit, wakes sensor if needed | Sensor stuck in sleep mode |
| 5. Configuration | Sets ±8g/±1000°/s, reads back | Register write failure |
| 6. I2C Stability | 20 rapid WHO_AM_I reads | Intermittent = loose wire or bad solder |
| 7. Raw Data Sanity | 10 samples: gravity ~1g? Gyro near 0? Values vary? | Stuck/dead sensor, wrong axis, frozen registers |

After tests complete, streams continuous formatted data at 10 Hz:
```
A: +0.012 -0.034 +1.002 | G:   +1.23   -0.45   +0.78 | 1.003g
A: +0.015 -0.031 +0.998 | G:   +1.12   -0.52   +0.81 | 0.999g  << motion
A: +1.234 +0.567 +2.345 | G: +245.12  -123.45  +89.01 | 2.723g  <<<< IMPACT!
```

### Troubleshooting Guide (printed on failure)

If **Test 2 fails** (no I2C device found):
1. VCC → ESP32 3V3 (not 5V)
2. GND → ESP32 GND
3. SDA → GPIO21
4. SCL → GPIO22
5. Check for loose jumper wires / bad breadboard rows
6. Check for bent pins on GY-521 module
7. Measure 3.3V on MPU6050 VCC with multimeter

If **Test 3 returns 0xFF/0x00**: sensor is likely dead — try a replacement module.

If **Test 6 has intermittent failures**: loose connection — reseat all jumper wires.

If **Test 7 gravity ≈ 0**: sensor registers respond but IMU core is non-functional — replace module.

### How to Use

1. Open Arduino IDE, load `ESPFirmware/SensorDiagnostic.ino`
2. Select ESP32 board + correct port
3. Upload (replaces BoxedUp.ino temporarily)
4. Open Serial Monitor at 115200 baud
5. Read through test results — first failure points to the problem
6. Once sensor works, re-upload `BoxedUp.ino`

### New Files

| File | Purpose |
|------|---------|
| `ESPFirmware/SensorDiagnostic.ino` | Standalone MPU6050 hardware diagnostic sketch |

---

*End of journal. Update this file after every implementation session.*
