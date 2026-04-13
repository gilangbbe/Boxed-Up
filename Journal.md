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
- Data collection mode not yet built (Phase 6)
- No `HKWorkoutSession` integration yet — Watch app may suspend during long rounds
- No error handling for WCSession disconnects mid-round
- Timer-based action advancement not yet implemented (currently only advances after punch)

---

*End of journal. Update this file after every implementation session.*
