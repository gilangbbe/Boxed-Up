# Boxed Up — Project Plan

## Overview
Motion-controlled boxing reaction game. **Apple Watch** captures real punches via CoreMotion and streams raw motion data to **iPhone** via WatchConnectivity. iPhone classifies punches with a Create ML model, acts as the sparring partner display, and scores responses in real-time.

**Communication chain:** Watch (CoreMotion) → iPhone (ML classification + sparring display + scoring)

---

## Phase 1: Project Foundation & Architecture

### 1.1 Restructure Xcode Project — Two Targets
- Existing **iOS target** ("Boxed Up") — sparring display, ML classification, scoring, game UI
- Add a new **watchOS target** ("Boxed Up Watch") — motion capture sensor
- Create a **Shared** group/folder for cross-platform code (models, game logic)
- Organize folder structure:
  ```
  Boxed Up/
  ├── Shared/                    # Cross-platform (iOS + watchOS)
  │   ├── Models/
  │   │   ├── PunchType.swift         # enum: jab, hook, uppercut
  │   │   ├── GameAction.swift        # guard/attack prompts
  │   │   ├── PunchResult.swift       # classification result + confidence
  │   │   └── WatchMessage.swift      # Codable messages for WatchConnectivity
  │   └── GameLogic/
  │       ├── ScoringEngine.swift     # correctness, reaction time, confidence scoring
  │       ├── RoundManager.swift      # round state, action sequences, timing
  │       └── CounterMapping.swift    # maps game actions → correct player counters
  ├── Boxed Up/                       # iPhone — sparring display + ML hub
  │   ├── Boxed_UpApp.swift
  │   ├── Views/
  │   │   ├── HomeView.swift           # start screen, settings, last session stats
  │   │   ├── SparringView.swift       # displays guards/attacks + punch feedback
  │   │   ├── ResultsView.swift        # post-round summary
  │   │   └── DataCollectionView.swift # training data recording control
  │   ├── WatchRelay/
  │   │   ├── WatchSessionManager.swift # WCSession delegate, receives motion data
  │   │   └── MotionDataBuffer.swift    # sliding window for ML input
  │   ├── MLClassifier/
  │   │   ├── PunchClassifier.swift    # Core ML inference wrapper
  │   │   └── PunchClassifier.mlmodel  # trained Create ML model
  │   └── ViewModels/
  │       ├── SparringViewModel.swift   # drives action sequence + scoring + classification
  │       └── DataCollectionViewModel.swift
  ├── Boxed Up Watch Watch App/                   # Apple Watch — motion sensor
  │   ├── Boxed_Up_WatchApp.swift
  │   ├── Views/
  │   │   ├── WatchHomeView.swift      # connection status, ready indicator
  │   │   ├── WatchGameView.swift      # minimal in-game display + haptic feedback
  │   │   └── WatchDataCollectionView.swift # recording status during training mode
  │   ├── MotionCapture/
  │   │   ├── WatchMotionManager.swift  # CMMotionManager on watchOS
  │   │   └── MotionStreamer.swift      # streams raw data to iPhone via WCSession
  │   └── WatchSessionManager.swift    # WCSession delegate on Watch side
  └── Assets.xcassets/
  ```

### 1.2 Shared Data Models

> **One-hand constraint:** Player wears Apple Watch on their punching wrist. All motion data comes from one arm — no left/right directional distinction is possible. The iPhone stays on a surface during gameplay for display computer action.

- `PunchType` — enum: `.jab`, `.hook`, `.uppercut`
- `GameAction` — enum with 6 actions (no directional variants):
  - **Attack actions** (opponent attacks, player must counter):
    - `.attackJab` — opponent jabs at player
    - `.attackHook` — opponent hooks at player
    - `.attackUppercut` — opponent uppercuts at player
  - **Opening actions** (opponent leaves a gap, player must exploit):
    - `.openHead` — opponent drops face guard
    - `.openBody` — opponent leaves torso exposed
    - `.openSide` — opponent leaves flank exposed
- `CounterMapping` — maps each `GameAction` to the correct `PunchType`:
  - `.attackJab` → **Uppercut** (duck under the jab, counter upward)
  - `.attackHook` → **Jab** (pull back, straight counter)
  - `.attackUppercut` → **Hook** (pivot aside, swing counter)
  - `.openHead` → **Jab** (fastest strike to exposed head)
  - `.openBody` → **Uppercut** (strike exposed body from below)
  - `.openSide` → **Hook** (swing into the exposed flank)
  - Each punch type is the correct answer exactly **2 times** (once as a counter, once as an exploit)
- `GameMessage` — no longer needed (was for MPC between iPhone and Mac)
- `WatchMessage` — Codable enum for Watch ↔ iPhone messages:
  - `.motionData([MotionSample])` — Watch → iPhone: batch of raw motion samples
  - `.motionStarted` / `.motionStopped` — Watch → iPhone: lifecycle signals
  - `.startCapture` / `.stopCapture` — iPhone → Watch: control motion recording
  - `.punchDetected(PunchType, correct: Bool)` — iPhone → Watch: haptic feedback
  - `.gameState(GameAction)` — iPhone → Watch: current prompt for minimal display
  - `.roundStart` / `.roundEnd` — iPhone → Watch: round lifecycle
- `MotionSample` — struct: timestamp, accX, accY, accZ, rotX, rotY, rotZ
- `Score` — struct: correctCount, totalCount, avgReactionTime, avgConfidence, totalPoints

**Files to create:** `Shared/Models/PunchType.swift`, `GameAction.swift`, `PunchResult.swift`, `WatchMessage.swift`, `Shared/GameLogic/CounterMapping.swift`

---

## Phase 2: WatchConnectivity Networking

### 2.1 WatchSessionManager (Watch ↔ iPhone)
- `WatchSessionManager` on both Watch and iPhone sides
- Uses `WCSession.default` with `sendMessage(_:replyHandler:)` for real-time data during active sessions
- **Watch → iPhone messages:**
  - `.motionData([MotionSample])` — batch of raw motion samples (sent at ~10-20 Hz in small batches)
  - `.motionStarted` / `.motionStopped` — lifecycle signals
- **iPhone → Watch messages:**
  - `.startCapture` / `.stopCapture` — control motion recording
  - `.punchDetected(PunchType, correct: Bool)` — feedback for Watch haptics
  - `.gameState(GameAction)` — current prompt for minimal Watch display
  - `.roundStart` / `.roundEnd` — round lifecycle
- Both apps must be **active/foreground** for real-time messaging — enforce this in the UX flow
- Fallback: if WCSession becomes unreachable mid-round, pause game

### 2.2 Info.plist Permissions
- watchOS: `NSMotionUsageDescription` — required for CoreMotion access on Watch

**Files to create:** `iOS/WatchRelay/WatchSessionManager.swift`, `watchOS/WatchSessionManager.swift`
**Files to modify:** watchOS Info.plist

---

## Phase 3: Watch Motion Capture & iPhone ML Pipeline

### 3.1 Watch: CoreMotion Data Capture
- `WatchMotionManager` — wraps `CMMotionManager.startDeviceMotionUpdates()` on watchOS
- Sampling rate: **50 Hz** (watchOS recommended max for sustained capture; saves battery vs 100 Hz)
- Capture: userAcceleration (x/y/z), rotationRate (x/y/z) → 6 channels
- `MotionStreamer` — batches samples (5-10 per message) and sends to iPhone via `WCSession.sendMessage`
- Starts/stops on command from iPhone (`startCapture` / `stopCapture` messages)
- Use `HKWorkoutSession` to keep the Watch app active during gameplay and prevent suspension

### 3.2 iPhone: Motion Data Reception & ML Classification
- `WatchSessionManager` receives motion data stream from Watch
- `MotionDataBuffer` — sliding window (e.g., 1 second = 50 samples at 50 Hz)
- Detect punch onset via acceleration magnitude threshold (e.g., > 1.5g) to trigger classification
- When punch detected, freeze the window, send to classifier
- `PunchClassifier.swift` wraps the Core ML model:
  - Takes `MotionDataBuffer` → creates `MLMultiArray` input
  - Returns `PunchType` + confidence (Double 0-1)
- After classification: evaluate with `ScoringEngine` locally, update UI, send haptic feedback to Watch

### 3.3 ML Model — Create ML Activity Classifier
- **Training**: Use Create ML (Xcode or Swift Playgrounds) Activity Classifier
  - Input: multivariate time series (6 features × window) — data recorded from Watch
  - Output: PunchType classification + confidence
  - Prediction window: ~25-50 samples (0.5-1 sec at 50 Hz)
- **Integration**: Drop `.mlmodel` into iOS target → auto-generates Swift class

### 3.4 Watch Haptic Feedback
- On receiving `.punchDetected` from iPhone, play haptic on Watch:
  - Correct punch: `WKInterfaceDevice.current().play(.success)`
  - Wrong punch: `WKInterfaceDevice.current().play(.failure)`
- More natural than iPhone haptics since Watch is on the punching wrist

### 3.5 Latency Budget
- Watch motion capture → WCSession send: ~20ms
- WCSession delivery to iPhone: ~30-80ms (varies)
- ML classification on iPhone: ~10-20ms
- **Total Watch-to-feedback: ~60-120ms** — excellent for real-time feedback
- No MPC hop — latency is significantly lower than 3-device chain

**Files to create:** `watchOS/MotionCapture/WatchMotionManager.swift`, `watchOS/MotionCapture/MotionStreamer.swift`, `iOS/WatchRelay/WatchSessionManager.swift`, `iOS/WatchRelay/MotionDataBuffer.swift`, `iOS/MLClassifier/PunchClassifier.swift`
**External step:** Record training data from Watch → train model in Create ML → export `.mlmodel`

---

## Phase 4: iPhone Sparring Display & Game UI

### 4.1 SparringView (iPhone — the main game screen)
- iPhone acts as the sparring partner display — placed on a stand/surface facing the player
- Large center display showing current action as:
  - Icon/symbol (e.g., fist icon for attacks, gap/opening icon for openings)
  - Text label ("ATTACK — JAB", "OPENING — HEAD")
  - Color coding (red = opponent attacking, green = opening to exploit)
- No directional left/right indicators (one-handed play)
- Animated transitions between actions (scale + fade)
- Timer bar showing remaining reaction window
- Punch feedback overlay: "JAB ✓" or "Wrong ✗" with brief flash
- Score display: current score, streak, round number

### 4.2 SparringViewModel
- `RoundManager` generates a sequence of `GameAction`s per round
  - Configurable: round length, action interval, difficulty (speed ramp)
  - Randomized but balanced (mix of attacks and openings)
- Flow:
  1. Display action on iPhone screen
  2. Send `.gameState(GameAction)` to Watch for minimal display
  3. Start reaction timer
  4. Receive motion data from Watch → classify punch
  5. `ScoringEngine` evaluates: correct counter? reaction time? confidence?
  6. Send `.punchDetected(PunchType, correct)` to Watch for haptic
  7. Update score + show feedback flash → next action
- Between rounds: show round summary

### 4.3 ScoringEngine (Shared)
- Points formula: `basePoints × reactionMultiplier × confidenceMultiplier`
  - Base: 100 for correct punch, 0 for wrong
  - Reaction multiplier: 2.0× (< 0.3s), 1.5× (< 0.5s), 1.0× (< 1.0s), 0.5× (> 1.0s)
  - Confidence multiplier: model confidence (0.0–1.0) → scales linearly
- Track streaks for bonus points
- Aggregate stats per round: accuracy %, avg reaction time, total score

### 4.4 HomeView
- Start button, settings (round count, difficulty, action interval)
- Watch connection status indicator — must be connected before starting
- Last session stats summary

### 4.5 ResultsView
- Post-round breakdown: accuracy, avg speed, best/worst punch, total score
- Play again / end session options

**Files to create:** `iOS/Views/HomeView.swift`, `iOS/Views/SparringView.swift`, `iOS/Views/ResultsView.swift`, `iOS/ViewModels/SparringViewModel.swift`, `Shared/GameLogic/ScoringEngine.swift`, `Shared/GameLogic/RoundManager.swift`

---

## Phase 5: Watch Game UI

### 5.1 WatchHomeView
- Connection status, "Ready" indicator when iPhone is connected
- Displays player name or session status

### 5.2 WatchGameView
- Minimal in-game display:
  - Current action text (mirrored from iPhone: "JAB", "HOOK", etc.)
  - Simple correct/wrong indicator
  - Round number
- Haptic feedback on each punch detection (success/failure)
- Keep screen awake during round via `HKWorkoutSession`

**Files to create:** `watchOS/Views/WatchHomeView.swift`, `watchOS/Views/WatchGameView.swift`, `watchOS/Boxed_Up_WatchApp.swift`

---

## Phase 6: Training Data Collection Mode

### 6.1 DataCollectionView (iPhone controls, Watch records)
- **iPhone UI** (`DataCollectionView`):
  - Pick punch type from segmented control (jab / hook / uppercut)
  - "Record" button → sends `.startCapture` to Watch → Watch captures 3 seconds of motion
  - Watch streams raw motion data back to iPhone during recording
  - iPhone saves labeled sessions to JSON files in app documents
  - "Export" button → share sheet to AirDrop/Files for Create ML training
  - Columns: timestamp, accX, accY, accZ, rotX, rotY, rotZ, label
- **Watch UI** (`WatchDataCollectionView`):
  - Minimal display: shows recording status ("Recording…" / "Done"), punch count
  - Haptic tap on recording start/stop
- This mode is crucial: quality of ML model depends on quantity + variety of training data
- **Important**: Training data is from the Watch's wrist-mounted sensors — different motion signature than phone-in-hand

**Files to create:** `iOS/Views/DataCollectionView.swift`, `iOS/ViewModels/DataCollectionViewModel.swift`, `watchOS/Views/WatchDataCollectionView.swift`

---

## Phase 7: Integration & Polish

### 7.1 End-to-End Flow Integration
- Wire up full loop: iPhone shows action → Watch captures punch → iPhone classifies → iPhone scores → Watch haptic
- Handle edge cases: punch during transition, double punch, no punch (timeout)
- Haptic feedback on Watch (primary) for correct/wrong punches
- Sound effects on iPhone (optional): punch sound on detection, chime on correct

### 7.2 Latency Optimization
- Measure and minimize Watch → iPhone round-trip latency
- ML inference should run on dedicated queue, not main thread
- Pre-warm CoreMotion on Watch and ML model on iPhone at session start
- Tune WCSession message batching (5-10 samples per message) for latency vs overhead balance

### 7.3 Edge Cases
- Watch disconnects mid-round → pause game, show reconnection prompt on iPhone
- Watch battery warning → surface in iPhone UI
- WCSession becomes unreachable (e.g., Watch app backgrounded) → pause + alert
- iPhone lock screen → keep game session alive with background audio or prevent auto-lock

---

## Implementation Order & Dependencies

```
Phase 1 (Foundation — 2 targets + models)
    ├── Phase 2 (WatchConnectivity) — depends on Phase 1 models
    ├── Phase 3 (Watch Motion + iPhone ML) — depends on Phase 1 + Phase 2
    │   └── Phase 6 (Data Collection) — can start as soon as WCSession works
    ├── Phase 4 (iPhone Sparring UI) — depends on Phase 1 + Phase 3
    └── Phase 5 (Watch UI) — depends on Phase 2
Phase 7 (Integration) — depends on all above
```

**Parallelizable:**
- Phase 4 (iPhone UI) and Phase 5 (Watch UI) can be built in parallel once WCSession works
- Phase 6 (data collection) should start as soon as WCSession works — gather training data early
- Phase 3 (motion pipeline) is the critical path — blocks iPhone UI

---

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Communication | WatchConnectivity only | Single framework, no MPC/server needed — Watch and iPhone are always paired |
| ML approach | Create ML Activity Classifier | Native Apple tooling, optimized for CoreMotion data, easy Core ML integration |
| ML model location | iPhone | More processing power than Watch; Watch sends raw data, iPhone classifies |
| Project structure | Single project, two targets (iOS + watchOS) | Shared code via target membership, simpler dependency management |
| Game display | iPhone screen | Acts as both sparring partner display and score board — placed on stand facing player |
| Sensor input | Apple Watch on punching wrist | More natural punching (hands free), wrist-mounted for better motion signature |
| Motion sampling | 50 Hz on Watch | watchOS recommended max for sustained capture; saves battery |
| Punch detection | Acceleration threshold + ML window | Quick onset detection, then ML classifies the type |
| Haptic feedback | Apple Watch | On the punching wrist — immediate physical feedback |

---

## Verification Plan

1. **Phase 1**: Both targets (iOS, watchOS) build and launch with placeholder UI
2. **Phase 2**: Watch app activates WCSession, sends test message to iPhone, iPhone receives and replies
3. **Phase 3**: Watch streams motion data at 50 Hz → iPhone receives, buffers, and logs to console; punch threshold triggers classification; ML model returns punch type (initially with dummy model)
4. **Phase 4**: iPhone displays rotating action prompts with animated transitions; punch feedback overlay works
5. **Phase 5**: Watch shows current action text and plays haptic on punch detection
6. **Phase 6**: Record 20+ samples per punch type from Watch; export and verify JSON format
7. **ML Training**: Train model in Create ML with Watch sensor data, achieve >85% validation accuracy
8. **Phase 7 (E2E)**: Full loop — iPhone shows action → Watch captures punch → iPhone classifies + scores → Watch haptic — all within <120ms perceived latency
9. **Stress test**: 3-minute round with rapid prompts, verify no crashes/memory leaks/Watch suspension

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| ML accuracy too low with limited training data | Start with 50+ samples per punch type; augment by varying speed/intensity; add "unknown" class |
| WCSession latency too high | Tune batch size (fewer samples per message = lower latency); monitor with os_signpost |
| Watch app suspended by watchOS | Use `HKWorkoutSession` to keep app active during gameplay (extended runtime) |
| CoreMotion permission denied on Watch | Clear usage description; graceful fallback with error message |
| Watch battery drain from 50 Hz motion | Limit game rounds to 3-5 min; show battery warning; reduce to 30 Hz if needed |
| iPhone screen auto-locks during round | Disable idle timer during active game session (`UIApplication.shared.isIdleTimerDisabled = true`) |
