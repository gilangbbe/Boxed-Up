# Boxed Up — Project Plan

## Overview
Motion-controlled boxing reaction game. **Apple Watch** captures real punches via CoreMotion on one hand, and a **DIY ESP32 Smart Glove** captures motion on the other hand via BLE. Both stream raw motion data to **iPhone**, which classifies punches with CNN models, acts as the sparring partner display, and scores responses in real-time. Dual-hand tracking enables combo detection and advanced game modes.

**Communication chain:**
- Watch (CoreMotion) → WCSession → iPhone (ML classification + sparring display + scoring)
- Smart Glove (MPU6050 + ESP32) → BLE → iPhone (ML classification)

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
  │   │   ├── PunchResult.swift       # classification result + confidence
  │   │   └── WatchMessage.swift      # Codable messages for WatchConnectivity
  │   └── GameLogic/
  │       ├── ScoringEngine.swift     # correctness, reaction time, confidence scoring
  │       └── RoundManager.swift      # round state, punch sequences, timing, difficulty
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

- `PunchType` — enum: `.jab`, `.hook`, `.uppercut` — the core game unit. Displayed directly to the player as the punch to throw.
- ~~`GameAction`~~ — **Removed.** Originally had 6 attack/opening actions requiring counter-mapping. Replaced by displaying `PunchType` directly.
- ~~`CounterMapping`~~ — **Removed.** No longer needed since the display shows the exact punch to throw.
- `WatchMessage` — Codable enum for Watch ↔ iPhone messages:
  - `.motionData([MotionSample])` — Watch → iPhone: batch of raw motion samples
  - `.motionStarted` / `.motionStopped` — Watch → iPhone: lifecycle signals
  - `.startCapture` / `.stopCapture` — iPhone → Watch: control motion recording
  - `.punchDetected(PunchType, correct: Bool)` — iPhone → Watch: haptic feedback
  - `.gameState(PunchType)` — iPhone → Watch: current punch prompt for display
  - `.roundStart` / `.roundEnd` — iPhone → Watch: round lifecycle
- `MotionSample` — struct: timestamp, accX, accY, accZ, rotX, rotY, rotZ
- `Score` — struct: correctCount, totalCount, avgReactionTime, avgConfidence, totalPoints

**Files to create:** `Shared/Models/PunchType.swift`, `PunchResult.swift`, `WatchMessage.swift`

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
  - `.gameState(PunchType)` — current punch prompt for minimal Watch display
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
- Large center display showing the **punch type to throw** directly:
  - Boxing figure icon (`figure.boxing`)
  - Bold text label: "JAB", "HOOK", or "UPPERCUT" in red
  - No attack/opening distinction — direct instruction
- No directional left/right indicators (one-handed play)
- Animated transitions between actions (scale + fade)
- Timer bar showing remaining reaction window (green → yellow → red countdown)
- Punch feedback overlay: "JAB ✓" or "Wrong ✗" with brief flash
- Timeout feedback: "TOO SLOW!" with clock icon
- Score display: current score, streak, round number
- Disconnect overlay: pauses game, shows reconnection prompt with option to end round

### 4.2 SparringViewModel
- `RoundManager` generates a sequence of `PunchType`s per round
  - Configurable: round length, action interval, difficulty (easy/normal/hard)
  - Randomized but balanced (no 3+ consecutive same punch type)
- Flow:
  1. Display punch type on iPhone screen ("JAB", "HOOK", "UPPERCUT")
  2. Send `.gameState(PunchType)` to Watch for minimal display
  3. Start reaction timer with countdown bar
  4. Receive motion data from Watch → two-stage ML pipeline (detect → classify)
  5. Direct comparison: `thrownPunch == expectedPunch` (no counter-mapping)
  6. `ScoringEngine` evaluates: correct? reaction time? confidence?
  7. Send `.punchDetected(PunchType, correct)` to Watch for haptic
  8. Sound effects: punch detected, correct/wrong, timeout, round complete
  9. Update score + show feedback flash → next action
- Timeout: if no punch within reaction window, record a miss and advance
- Disconnect handling: pause game on Watch disconnect, resume on reconnect
- ML inference runs on dedicated background queue (`com.boxedup.ml`)
- Between rounds: show round summary

### 4.3 ScoringEngine (Shared)
- Points formula: `basePoints × reactionMultiplier × confidenceMultiplier`
  - Base: 100 for correct punch, 0 for wrong
  - Reaction multiplier: 2.0× (< 0.3s), 1.5× (< 0.5s), 1.0× (< 1.0s), 0.5× (> 1.0s)
  - Confidence multiplier: model confidence (0.0–1.0) → scales linearly
- Track streaks for bonus points
- Aggregate stats per round: accuracy %, avg reaction time, total score

### 4.4 HomeView
- Watch connection status indicator — must be connected before starting
- **Difficulty picker** — segmented control (Easy / Normal / Hard) bound to `RoundManager.Config.Difficulty`
- Start Round button (disabled when Watch not connected)
- Collect Training Data button → enters data collection mode

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
  - Boxing figure icon + current punch type text ("JAB", "HOOK", "UPPERCUT") in red
  - Simple correct/wrong indicator (checkmark/xmark)
- Haptic feedback on each punch detection (success/failure)
- Keep screen awake during round via `HKWorkoutSession`

**Files to create:** `watchOS/Views/WatchHomeView.swift`, `watchOS/Views/WatchGameView.swift`, `watchOS/Boxed_Up_WatchApp.swift`

---

## Phase 6: Training Data Collection Mode

### 6.1 DataCollectionView (iPhone controls, Watch records)
- **iPhone UI** (`DataCollectionView`):
  - Pick punch type from segmented control (jab / hook / uppercut / other)
  - "Record" button → 3-2-1 countdown → sends `.startCapture` to Watch → Watch captures 3 seconds of motion
  - Watch streams raw motion data back to iPhone during recording
  - iPhone saves labeled sessions as individual CSV files organized in labeled directories:
    ```
    Documents/TrainingData/
    ├── jab/
    │   ├── session_20260414_143025_001.csv
    │   └── ...
    ├── hook/
    │   └── ...
    ├── uppercut/
    │   └── ...
    └── other/
        └── ...
    ```
  - Each CSV file: `timestamp,accX,accY,accZ,rotX,rotY,rotZ`
  - Session count tracker per label with color-coded progress (red < 20, orange < 50, green ≥ 50)
  - "Export" button → consolidated CSV via share sheet (includes sessionId + label columns)
  - "Delete All" button with confirmation
  - Watch connection status indicator
- **Watch UI** (`WatchDataCollectionView`):
  - Minimal display: shows recording status ("Recording…" / "Ready"), haptic tap on start/stop
  - Watch enters data collection mode via new `.enterDataCollection` / `.exitDataCollection` WatchMessages
- **Data format compatibility:**
  - Individual CSVs in labeled directories → direct input for `MLActivityClassifier.DataSource.labeledDirectories(at:)`
  - Consolidated export CSV → compatible with `MLDataTable` / `DataFrame` workflows

### 6.2 Data Collection Requirements

| Label | Purpose | Min Sessions | Recommended | Notes |
|-------|---------|-------------|-------------|-------|
| **Jab** | Punch classifier + detector (positive) | 50 | 100+ | Straight forward punch |
| **Hook** | Punch classifier + detector (positive) | 50 | 100+ | Sweeping side punch |
| **Uppercut** | Punch classifier + detector (positive) | 50 | 100+ | Upward rising punch |
| **Other** | Detector only (negative class) | 50 | 100+ | Idle, walking, wrist adjustment, waving |

**Best practices for quality data:**
- Vary speed and intensity (light, medium, full power)
- Include both standing and sitting positions
- Record at different times (fresh vs fatigued)
- Always wear Watch on the same wrist used during gameplay
- For "other": include diverse non-punch movements (scrolling phone, drinking water, scratching, walking, clapping)
- Recording duration: 3 seconds per session at 50 Hz = 150 samples

**Files created:** `Shared/Models/DataCollectionLabel.swift`, `iOS/Views/DataCollectionView.swift`, `iOS/ViewModels/DataCollectionViewModel.swift`, `watchOS/Views/WatchDataCollectionView.swift`
**Files modified:** `WatchMessage.swift` (added enterDataCollection/exitDataCollection), `Boxed_UpApp.swift`, `HomeView.swift`, `Boxed_Up_WatchApp.swift`, `WatchSessionManager.swift`

---

## ML Model Architecture

### Model 1: Punch Type Classifier (Critical — Core Game Mechanic)

**Purpose:** Classify the wrist-mounted motion into jab, hook, or uppercut.

| Parameter | Value |
|-----------|-------|
| Framework | ~~CreateML `MLActivityClassifier`~~ → **PyTorch Conv1D → coremltools** |
| Input | Single `motionData` Float32 tensor [1, 6, 50] — 6 channels × 50 time steps |
| Prediction window | 50 samples (1.0 second) |
| Classes | 3: jab, hook, uppercut |
| Output | `classLabel` + probability dictionary |
| Model file | `PunchClassifier_CNN.mlmodel` |

**Why CNN 1D (replaces Activity Classifier):**
- **Better generalization** — CreateML Activity Classifier (LSTM) overfitted on limited training data (50% validation error). CNN 1D generalizes significantly better.
- **Stateless** — No recurrent state to manage between predictions, eliminating the LSTM state carryover bug that caused false re-detections.
- **Translation-invariant** — Learns local temporal punch patterns regardless of position in window.
- **Simpler input** — Single [1, 6, windowSize] tensor instead of 6 separate arrays + hidden state.

**Architecture:** 3× Conv1D layers (increasing channels) + ReLU activations + Global Average Pooling + Fully Connected classifier.

**Integration:** `PunchClassifierService` wraps the CNN model, builds the [1, 6, 50] input tensor from `MotionSample` arrays.

### Model 2: Punch Detector (Recommended — Replaces Threshold)

**Purpose:** Binary detection of "is this a punch?" — replaces the crude 1.5g acceleration magnitude threshold.

| Parameter | Value |
|-----------|-------|
| Framework | ~~CreateML `MLActivityClassifier`~~ → **PyTorch Conv1D → coremltools** |
| Input | Single `motionData` Float32 tensor [1, 6, 25] — 6 channels × 25 time steps |
| Prediction window | 25 samples (0.5 second) — smaller for faster detection |
| Classes | 2: punch, other |
| Output | `classLabel` + probability dictionary |
| Model file | `PunchDetector_CNN.mlmodel` |

**Why separate from Model 1:**
- Smaller window → faster detection → more precise reaction time measurement
- Dedicated false positive rejection (ignores wrist adjustments, waves, etc.)
- Punch classifier can focus purely on type discrimination
- Different optimal window sizes (0.5s detection vs 1.0s classification)

**Training data mapping:**
- "punch" class: **All** jab + hook + uppercut recordings combined
- "other" class: All recordings labeled "other"

**Training:** Both CNN models trained via PyTorch, converted to Core ML using coremltools. See `TrainModels.swift` for the CreateML version (kept for reference on main branch).

### Model 3: Punch Quality Estimator (Future / Optional)

**Purpose:** Rate punch power/form for enhanced scoring.

| Parameter | Value |
|-----------|-------|
| Framework | Create ML Tabular Regressor |
| Input | Aggregated features: peak acceleration, jerk, rotation magnitude, duration |
| Output | Quality score (0.0–1.0) |

**Integration:** Adds a `qualityMultiplier` to `ScoringEngine`:
```
finalScore = basePoints × reactionMultiplier × confidence × qualityMultiplier
```

**Status:** Not needed for MVP. Can be trained after Models 1 & 2 are working.

### Two-Stage Runtime Pipeline

```
Watch (50 Hz motion) → WCSession → iPhone
                                      │
                                      ▼
                                ┌──────────────┐
                                │  Model 2:    │  (25-sample window, continuous)
                                │  Punch       │───── "other" → discard
                                │  Detector    │
                                └──────┬───────┘
                                       │ "punch" detected
                                       ▼
                                ┌──────────────┐
                                │  Model 1:    │  (50-sample window)
                                │  Punch Type  │
                                │  Classifier  │
                                └──────┬───────┘
                                       │ jab / hook / uppercut + confidence
                                       ▼
                                ┌──────────────┐
                                │  Scoring     │ → UI update → Watch haptic
                                │  Engine      │
                                └──────────────┘
```

**Latency budget (two-stage):**
- Watch → iPhone (WCSession): ~30-80ms
- Model 2 detection: ~5ms
- Model 1 classification: ~10-20ms
- **Total: ~45-105ms** — well within real-time requirements

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

## Phase 8: DIY Smart Glove (ESP32 + MPU6050 via BLE)

> **Goal:** Build a student-friendly, low-cost smart glove for the non-Watch hand using off-the-shelf components. The glove streams 6-axis IMU data (accelerometer + gyroscope) to the iPhone over Bluetooth Low Energy (BLE), mirroring the Apple Watch's motion data format. This enables dual-hand punch detection and combo game modes.

### 8.1 Component List

All components are widely available on Amazon, AliExpress, Adafruit, or local electronics shops. Total cost: **~$15–25 USD**.

| Component | Model | Qty | Est. Price | Notes |
|-----------|-------|-----|------------|-------|
| Microcontroller | **ESP32-WROOM-32 DevKit V1** (30-pin) | 1 | $5–8 | Built-in WiFi + BLE, 240 MHz dual-core, 3.3V logic. The most common student board. |
| IMU Sensor | **MPU6050** (GY-521 breakout) | 1 | $2–3 | 6-axis: 3-axis accelerometer + 3-axis gyroscope. I2C interface. Matches Watch's 6 channels. |
| Battery | **3.7V LiPo 500mAh** (JST-PH 2.0 connector) | 1 | $3–5 | ~2–3 hours runtime at 50 Hz sampling + BLE. Rechargeable. |
| Charger module | **TP4056 USB-C** (with protection circuit) | 1 | $1–2 | Charges LiPo via USB-C. Has overcurrent/overdischarge protection built-in. |
| Switch | **SPDT slide switch** (SS12D00) | 1 | $0.50 | Power on/off. Inline between battery and ESP32. |
| Wires | **Dupont jumper wires** (female-female) | 6 | $1 (pack) | For breadboard prototyping. Replace with soldered connections for final build. |
| Glove | **Fingerless workout glove** or boxing wrap | 1 | $3–5 | Any snug glove that exposes fingers. Mount electronics on the back of the wrist. |
| Mounting | **Velcro adhesive strips** + **small zip ties** | — | $1–2 | Secure PCB and battery to glove. Removable for charging. |
| (Optional) Breadboard | **Mini breadboard** (170 tie-points) | 1 | $1 | For prototyping only — not needed in final glove. |
| (Optional) Perfboard | **5×7cm perfboard** | 1 | $0.50 | For soldering the final compact circuit. |

### 8.2 Wiring Diagram

```
                     ESP32 DevKit V1
                    ┌───────────────┐
                    │               │
  MPU6050 VCC ──────┤ 3V3      VIN ├──── TP4056 OUT+ (via switch)
  MPU6050 GND ──────┤ GND      GND ├──── TP4056 OUT- / Battery GND
  MPU6050 SDA ──────┤ GPIO21       │
  MPU6050 SCL ──────┤ GPIO22       │
  MPU6050 INT ──────┤ GPIO19       │     (optional — for interrupt-driven reads)
                    │               │
                    └───────────────┘

        MPU6050 (GY-521 breakout)        TP4056 USB-C Module
       ┌──────────────────┐            ┌──────────────────┐
       │  VCC  SDA  SCL   │            │  IN+   OUT+      │
       │  GND  INT  AD0   │            │  IN-   OUT-      │
       └──────────────────┘            │  B+    B-        │
          │    │    │                   └──────────────────┘
          │    │    │                      │       │
          │    │    └── GPIO22            USB-C   LiPo Battery
          │    └─────── GPIO21           (charge)  (3.7V)
          └──────────── 3V3 + GND

  Power path:
  LiPo 3.7V ──→ TP4056 B+/B- (charge + protection)
  TP4056 OUT+ ──→ Slide Switch ──→ ESP32 VIN
  TP4056 OUT- ──→ ESP32 GND
```

**Wiring connections (6 wires total):**

| MPU6050 Pin | ESP32 Pin | Wire Color (suggested) | Purpose |
|-------------|-----------|----------------------|---------|
| VCC | 3V3 | **Red** | 3.3V power supply |
| GND | GND | **Black** | Ground |
| SDA | GPIO21 | **Blue** | I2C data line |
| SCL | GPIO22 | **Yellow** | I2C clock line |
| INT | GPIO19 | **Green** | Data-ready interrupt (optional) |
| AD0 | GND | **Black** (shared) | Sets I2C address to 0x68 (default) |

**Power connections (3 wires):**

| From | To | Purpose |
|------|----|---------|
| LiPo + | TP4056 B+ | Battery charging input |
| LiPo – | TP4056 B– | Battery ground |
| TP4056 OUT+ | Slide switch → ESP32 VIN | Regulated power to ESP32 (via switch) |
| TP4056 OUT– | ESP32 GND | Common ground |

> **Safety note:** Never short-circuit a LiPo battery. Always use the TP4056 protection circuit. If the battery puffs or gets hot, disconnect immediately and dispose safely.

### 8.3 Assembly Steps

#### Step 1: Breadboard Prototype (test everything first)
1. Place ESP32 on the breadboard straddling the center channel
2. Wire MPU6050 to ESP32 following the table above (VCC→3V3, GND→GND, SDA→21, SCL→22)
3. Power ESP32 via USB-C from computer for programming
4. Upload the firmware (Section 8.4) via Arduino IDE
5. Open Serial Monitor — verify IMU readings printing at 50 Hz
6. Open the iPhone app — verify BLE connection and motion data streaming
7. **Do not proceed to soldering until BLE streaming works reliably**

#### Step 2: Solder to Perfboard (compact circuit)
1. Cut perfboard to ~3×4 cm (just big enough for ESP32 + MPU6050 breakout)
2. Solder header pins for ESP32 and MPU6050 (so they're removable)
3. Solder the 4 IMU wires (VCC, GND, SDA, SCL) on the underside
4. Solder TP4056 output wires with the slide switch inline on the positive rail
5. Add JST connector for LiPo battery (so battery is detachable)
6. Hot-glue the TP4056 module to the edge of the perfboard

#### Step 3: Mount on Glove
1. Cut a small pouch from fabric or use a wrist sweatband
2. Attach velcro strips to the back of the glove (wrist area) and to the perfboard
3. Position the ESP32 + MPU6050 on the **back of the wrist** (same position as Apple Watch on the other hand)
4. Secure the LiPo battery next to the board with a velcro strap
5. Route the power switch to an accessible position
6. Ensure IMU is **firmly mounted** — loose mounting = noisy data

```
  Glove Layout (back of hand, wrist area):
  ┌─────────────────────────┐
  │                         │
  │   ┌─────────┐           │
  │   │ ESP32 + │  [Switch] │
  │   │ MPU6050 │           │
  │   └─────────┘           │
  │   ┌─────────┐           │
  │   │ LiPo    │           │
  │   │ Battery │           │
  │   └─────────┘           │
  │        ┌──────┐         │
  │        │TP4056│         │
  │        └──────┘         │
  │   (USB-C port exposed   │
  │    for charging)        │
  └─────────────────────────┘
```

### 8.4 ESP32 Firmware

**Development environment:** Arduino IDE 2.x (free, cross-platform, student-friendly)

**Arduino IDE setup:**
1. File → Preferences → Additional Board Manager URLs → add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
2. Tools → Board Manager → search "esp32" → install **esp32 by Espressif Systems**
3. Tools → Board → select **ESP32 Dev Module**
4. Install libraries: **MPU6050** by Electronic Cats, **ArduinoBLE** (or use built-in ESP32 BLE)

**Firmware behavior:**
- On boot: initialize MPU6050 at ±8g accelerometer range, ±1000°/s gyroscope range
- Start BLE peripheral advertising as `"BoxedUpGlove"`
- Define a BLE GATT service with a single **Notify** characteristic for motion data
- Sample MPU6050 at **50 Hz** (matches Apple Watch sampling rate)
- Pack each sample as a **28-byte binary packet**: `[timestamp(8) + accX(4) + accY(4) + accZ(4) + rotX(4) + rotY(4) + rotZ(4)]` — all Float32 except timestamp (Float64/UInt32)
- Batch 5 samples per BLE notification (140 bytes, well under BLE MTU of 512)
- LED indicator: blink while advertising, solid when connected

**Firmware sketch outline:**

```cpp
// BoxedUpGlove.ino — ESP32 firmware for the smart glove
// Streams MPU6050 6-axis IMU data over BLE at 50 Hz

#include <Wire.h>
#include <MPU6050.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// BLE UUIDs (custom — must match iPhone app)
#define SERVICE_UUID        "12345678-1234-1234-1234-123456789ABC"
#define MOTION_CHAR_UUID    "12345678-1234-1234-1234-123456789ABD"
#define CONTROL_CHAR_UUID   "12345678-1234-1234-1234-123456789ABE"

MPU6050 mpu;
BLECharacteristic* motionChar;
BLECharacteristic* controlChar;

bool deviceConnected = false;
bool capturing = false;

// Sampling
const int SAMPLE_RATE_HZ = 50;
const int SAMPLE_INTERVAL_US = 1000000 / SAMPLE_RATE_HZ;  // 20000 µs
const int BATCH_SIZE = 5;

// Calibration offsets (set during calibration step)
int16_t axOff = 0, ayOff = 0, azOff = 0;
int16_t gxOff = 0, gyOff = 0, gzOff = 0;

// --- BLE Callbacks ---
class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* s)    { deviceConnected = true;  }
    void onDisconnect(BLEServer* s) { deviceConnected = false; capturing = false; }
};

class ControlCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* c) {
        uint8_t* data = c->getData();
        if (c->getLength() > 0) {
            capturing = (data[0] == 0x01);  // 0x01 = start, 0x00 = stop
        }
    }
};

void setup() {
    Serial.begin(115200);
    Wire.begin(21, 22);           // SDA=21, SCL=22
    Wire.setClock(400000);        // 400 kHz I2C fast mode

    // Init MPU6050
    mpu.initialize();
    mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_8);   // ±8g
    mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_1000);  // ±1000°/s
    mpu.setDLPFMode(MPU6050_DLPF_BW_42);              // 42 Hz low-pass filter

    // Calibrate (keep glove still during startup)
    calibrateSensor();

    // Init BLE
    BLEDevice::init("BoxedUpGlove");
    BLEServer* server = BLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());

    BLEService* service = server->createService(SERVICE_UUID);

    motionChar = service->createCharacteristic(
        MOTION_CHAR_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    motionChar->addDescriptor(new BLE2902());

    controlChar = service->createCharacteristic(
        CONTROL_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    controlChar->setCallbacks(new ControlCallbacks());

    service->start();
    BLEAdvertising* adv = BLEDevice::getAdvertising();
    adv->addServiceUUID(SERVICE_UUID);
    adv->start();

    Serial.println("[Glove] BLE advertising as 'BoxedUpGlove'");
}

void loop() {
    if (!deviceConnected || !capturing) {
        delay(100);
        return;
    }

    // Collect a batch of samples
    uint8_t buffer[BATCH_SIZE * 28];  // 5 samples × 28 bytes each
    for (int i = 0; i < BATCH_SIZE; i++) {
        unsigned long t = micros();

        int16_t ax, ay, az, gx, gy, gz;
        mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

        // Convert to physical units (g and °/s) as Float32
        // ±8g range: sensitivity = 4096 LSB/g
        // ±1000°/s range: sensitivity = 32.8 LSB/(°/s)
        float accX = (float)(ax - axOff) / 4096.0f;
        float accY = (float)(ay - ayOff) / 4096.0f;
        float accZ = (float)(az - azOff) / 4096.0f;
        float rotX = (float)(gx - gxOff) / 32.8f;
        float rotY = (float)(gy - gyOff) / 32.8f;
        float rotZ = (float)(gz - gzOff) / 32.8f;

        // Pack into buffer: [timestamp(4) + accXYZ(12) + rotXYZ(12)] = 28 bytes
        uint32_t ts = (uint32_t)(t / 1000);  // milliseconds
        int offset = i * 28;
        memcpy(&buffer[offset +  0], &ts,   4);
        memcpy(&buffer[offset +  4], &accX, 4);
        memcpy(&buffer[offset +  8], &accY, 4);
        memcpy(&buffer[offset + 12], &accZ, 4);
        memcpy(&buffer[offset + 16], &rotX, 4);
        memcpy(&buffer[offset + 20], &rotY, 4);
        memcpy(&buffer[offset + 24], &rotZ, 4);

        // Wait for next sample interval
        unsigned long elapsed = micros() - t;
        if (elapsed < SAMPLE_INTERVAL_US) {
            delayMicroseconds(SAMPLE_INTERVAL_US - elapsed);
        }
    }

    // Send batch over BLE notify
    motionChar->setValue(buffer, BATCH_SIZE * 28);
    motionChar->notify();
}

void calibrateSensor() {
    Serial.println("[Glove] Calibrating — keep still for 2 seconds...");
    long sumAx=0, sumAy=0, sumAz=0, sumGx=0, sumGy=0, sumGz=0;
    int n = 100;
    for (int i = 0; i < n; i++) {
        int16_t ax, ay, az, gx, gy, gz;
        mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
        sumAx += ax; sumAy += ay; sumAz += az;
        sumGx += gx; sumGy += gy; sumGz += gz;
        delay(20);
    }
    axOff = sumAx / n;
    ayOff = sumAy / n;
    azOff = (sumAz / n) - 4096;  // Remove gravity (1g = 4096 LSB at ±8g)
    gxOff = sumGx / n;
    gyOff = sumGy / n;
    gzOff = sumGz / n;
    Serial.println("[Glove] Calibration complete.");
}
```

### 8.5 iPhone BLE Integration (CoreBluetooth)

The iPhone app needs a new `GloveSessionManager` that mirrors the existing `PhoneSessionManager` (WatchConnectivity) but uses CoreBluetooth to communicate with the ESP32.

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────┐
│                        iPhone App                                │
│                                                                  │
│  PhoneSessionManager ←── WCSession ←── Apple Watch (right hand)  │
│         │                                                        │
│         └──→ MotionDataBuffer (right) ──→ ML Pipeline            │
│                                              ↑                   │
│  GloveSessionManager ←── CoreBluetooth ←── ESP32 Glove (left)   │
│         │                                                        │
│         └──→ MotionDataBuffer (left) ───────┘                    │
│                                                                  │
│  SparringViewModel                                               │
│    ├── rightHandBuffer (from Watch)                              │
│    ├── leftHandBuffer  (from Glove)                              │
│    └── DualHandProcessor (combo detection)                       │
└─────────────────────────────────────────────────────────────────┘
```

**New files to create:**

| File | Purpose |
|------|---------|
| `Boxed Up/BLERelay/GloveSessionManager.swift` | CoreBluetooth central manager. Scans for `"BoxedUpGlove"`, connects, subscribes to motion characteristic, parses binary packets into `MotionSample` arrays. Provides `onMotionData` callback matching `PhoneSessionManager` API. |
| `Boxed Up/BLERelay/GloveConstants.swift` | BLE UUIDs, packet format constants. Matches firmware UUIDs. |
| `Boxed Up/ViewModels/DualHandProcessor.swift` | Combines left + right hand motion buffers. Detects combos (e.g., left-jab → right-hook sequence). Provides combo scoring. |

**`GloveSessionManager` responsibilities:**
- Scan for BLE peripherals advertising `SERVICE_UUID`
- Connect and discover the motion notify characteristic + control write characteristic
- Subscribe to notifications → parse each 140-byte payload into 5 `MotionSample` structs
- Write `0x01` / `0x00` to control characteristic to start/stop capture (mirrors WCSession `.startCapture` / `.stopCapture`)
- Expose `isGloveConnected: Bool` for UI status
- Handle disconnect/reconnect gracefully (auto-reconnect within game round)

**Binary packet parsing (Swift):**

```swift
func parseMotionBatch(data: Data) -> [MotionSample] {
    let sampleSize = 28  // 4 + 6×4 bytes
    var samples: [MotionSample] = []

    for i in stride(from: 0, to: data.count, by: sampleSize) {
        guard i + sampleSize <= data.count else { break }

        let ts: UInt32 = data.subdata(in: i..<i+4).withUnsafeBytes { $0.load(as: UInt32.self) }
        let accX: Float32 = data.subdata(in: i+4..<i+8).withUnsafeBytes { $0.load(as: Float32.self) }
        let accY: Float32 = data.subdata(in: i+8..<i+12).withUnsafeBytes { $0.load(as: Float32.self) }
        let accZ: Float32 = data.subdata(in: i+12..<i+16).withUnsafeBytes { $0.load(as: Float32.self) }
        let rotX: Float32 = data.subdata(in: i+16..<i+20).withUnsafeBytes { $0.load(as: Float32.self) }
        let rotY: Float32 = data.subdata(in: i+20..<i+24).withUnsafeBytes { $0.load(as: Float32.self) }
        let rotZ: Float32 = data.subdata(in: i+24..<i+28).withUnsafeBytes { $0.load(as: Float32.self) }

        samples.append(MotionSample(
            timestamp: TimeInterval(ts) / 1000.0,
            accX: Double(accX), accY: Double(accY), accZ: Double(accZ),
            rotX: Double(rotX), rotY: Double(rotY), rotZ: Double(rotZ)
        ))
    }
    return samples
}
```

### 8.6 Dual-Hand Data Collection

Extend the existing data collection mode to record from both hands simultaneously:

- **DataCollectionView** gains a hand selector: **Right (Watch)** / **Left (Glove)** / **Both**
- When recording "Both", the countdown triggers capture on Watch (via WCSession) AND Glove (via BLE write) simultaneously
- Saves separate CSV files per hand: `jab/right_session_001.csv`, `jab/left_session_001.csv`
- Train separate ML models per hand (motion signatures differ between dominant/non-dominant hand)
- Alternatively, train a single model with a `hand` feature column — test both approaches

### 8.7 Dual-Hand ML Pipeline

**Option A: Separate models per hand (recommended for v1)**
- Reuse existing CNN 1D architecture (PunchDetector + PunchClassifier)
- Train a second pair of models on left-hand data: `PunchClassifier_Left_CNN.mlmodel`, `PunchDetector_Left_CNN.mlmodel`
- iPhone runs both pipelines in parallel on the ML queue

**Option B: Single unified model (future optimization)**
- 12-channel input `[1, 12, windowSize]` — 6 channels per hand concatenated
- Requires synchronized timestamps between Watch and Glove (clock alignment)
- More complex but can learn cross-hand patterns

### 8.8 Combo Game Mode (New Feature Unlocked by Dual-Hand)

With both hands tracked, new game modes become possible:

**Combo sequences:**
- Display a sequence of punches with hand indicators: `L-JAB → R-HOOK → L-UPPERCUT`
- Player must execute the full combo in order within the time window
- Score based on accuracy, timing, and rhythm between punches

**New models/types needed:**

| File | Purpose |
|------|---------|
| `Shared/Models/HandSide.swift` | `enum HandSide: String, Codable { case left, right }` |
| `Shared/Models/ComboAction.swift` | `struct ComboAction { let hand: HandSide; let punch: PunchType }` |
| `Shared/GameLogic/ComboManager.swift` | Generates combo sequences, tracks progress through combo steps, validates order |

**Game flow for combo mode:**
1. iPhone displays full combo sequence (e.g., 3–5 punches with hand indicators)
2. Player executes each punch in order
3. Each punch validated independently (correct hand + correct type)
4. Combo scored as a whole: all-correct bonus, rhythm bonus, speed bonus
5. Partial credit for getting some punches right

**UI updates:**
- `SparringView` gains a combo display mode: horizontal punch sequence with L/R indicators
- Current punch highlighted, completed punches grayed/checked
- `HomeView` gains a game mode picker: **Single Hand** / **Combo**

### 8.9 Latency Budget (Glove Path)

| Stage | Latency |
|-------|---------|
| MPU6050 I2C read | ~1ms |
| ESP32 BLE notify | ~7.5–15ms (connection interval) |
| iPhone CoreBluetooth receive | ~5–10ms |
| ML inference | ~10–20ms |
| **Total glove-to-classification** | **~25–50ms** |

> BLE connection interval is configurable. iOS typically negotiates 15–30ms intervals. For gaming, request the minimum (7.5ms) via `CBConnectPeripheral` connection parameters. The ESP32 should set `BLEDevice::setMTU(512)` for larger payloads.

### 8.10 Info.plist Changes

Add to the iOS target's `Info.plist`:
- `NSBluetoothAlwaysUsageDescription` — "Boxed Up uses Bluetooth to connect to your Smart Glove for motion tracking."
- `NSBluetoothPeripheralUsageDescription` — (iOS 12 fallback) same description
- Add `bluetooth-central` to `UIBackgroundModes` if background BLE is needed (optional for v1)

### 8.11 Glove Calibration & Axis Alignment

The MPU6050's axis orientation will differ from the Apple Watch's CoreMotion coordinate system. To ensure the same ML models work for both hands (or to train comparable models):

1. **Firmware calibration** — On boot, the ESP32 averages 100 samples at rest and subtracts offsets (see `calibrateSensor()` in firmware). This zeros out accelerometer bias and gyroscope drift.
2. **Mounting orientation** — Mount the MPU6050 breakout board with the **component side facing outward** (away from skin) and the **X-axis pointing toward the fingers**. This roughly matches Apple Watch's coordinate frame:
   - X → toward fingers (along forearm)
   - Y → across wrist (lateral)
   - Z → outward from back of wrist (normal)
3. **Axis remapping** — If mounting differs, add a rotation matrix in the firmware or in `GloveSessionManager` to remap axes. A simple sign-flip or axis-swap in the parsing function is usually sufficient.
4. **Validation** — Record the same punch type on both hands, plot the 6 channels, verify they show similar patterns.

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
Phase 8 (Smart Glove) — depends on Phase 7 (working single-hand game)
    ├── 8.1–8.4 (Hardware + Firmware) — independent of iOS code
    ├── 8.5 (iPhone BLE Integration) — depends on 8.4 (working firmware)
    ├── 8.6 (Dual-Hand Data Collection) — depends on 8.5 + Phase 6
    ├── 8.7 (Dual-Hand ML) — depends on 8.6 (training data)
    └── 8.8 (Combo Game Mode) — depends on 8.7 + Phase 4
```

**Parallelizable:**
- Phase 4 (iPhone UI) and Phase 5 (Watch UI) can be built in parallel once WCSession works
- Phase 6 (data collection) should start as soon as WCSession works — gather training data early
- Phase 3 (motion pipeline) is the critical path — blocks iPhone UI
- Phase 8 hardware (8.1–8.4) can be built and tested independently of any iOS code changes

---

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Communication | WatchConnectivity + CoreBluetooth | WCSession for Watch (paired), BLE for ESP32 glove (standard IoT protocol) |
| ML approach | ~~CreateML Activity Classifier~~ → **PyTorch CNN 1D** | CNN 1D generalizes better than LSTM on limited data, stateless (no state carryover bugs), converted via coremltools |
| ML model location | iPhone | More processing power than Watch/ESP32; both peripherals send raw data, iPhone classifies |
| Project structure | Single project, two targets (iOS + watchOS) | Shared code via target membership, simpler dependency management |
| Game display | iPhone screen | Acts as both sparring partner display and score board — placed on stand facing player |
| Right hand sensor | Apple Watch on punching wrist | More natural punching (hands free), wrist-mounted for better motion signature |
| Left hand sensor | DIY ESP32 + MPU6050 smart glove | Low-cost (~$15–25), student-accessible, BLE streaming, same 6-axis data as Watch |
| Glove IMU | MPU6050 (GY-521) | Cheapest 6-axis IMU, I2C, extensive Arduino library support, matches Watch's 6 channels |
| Glove MCU | ESP32-WROOM-32 | Built-in BLE, ~$5, Arduino IDE compatible, most popular student IoT board |
| Motion sampling | 50 Hz on both Watch and Glove | Consistent sampling rate across both hands for model compatibility |
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
10. **Phase 8.1–8.3 (Glove HW)**: ESP32 + MPU6050 wired and powered, Serial Monitor shows IMU data at 50 Hz, calibration offsets applied
11. **Phase 8.4 (Glove BLE)**: iPhone discovers "BoxedUpGlove" in BLE scan, connects, receives motion notifications, parses into `MotionSample` array — verify values match Serial Monitor output
12. **Phase 8.5 (Glove Integration)**: iPhone receives glove motion data and feeds through ML pipeline — punch detection works from glove hand
13. **Phase 8.6 (Dual Collection)**: Record 20+ left-hand samples per punch type; export and verify CSV format; compare motion patterns to right-hand data
14. **Phase 8.7 (Dual ML)**: Train left-hand CNN models, achieve >85% validation accuracy
15. **Phase 8.8 (Combo Mode)**: Full dual-hand combo loop — iPhone displays combo → both hands punch in sequence → classified and scored correctly

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
| MPU6050 noisy data | Apply calibration offsets at boot; use on-chip DLPF (42 Hz low-pass); ensure firm mounting on glove (loose = noise) |
| ESP32 BLE disconnects mid-game | Implement auto-reconnect in `GloveSessionManager`; pause game on disconnect (same pattern as Watch) |
| LiPo battery safety | Always use TP4056 with protection circuit; never puncture/short-circuit; don't charge unattended initially |
| MPU6050 axis mismatch vs Watch | Document mounting orientation; add axis remap in firmware or parser; validate with side-by-side recording |
| BLE latency spikes | Request minimum connection interval (7.5ms); batch 5 samples per notification; avoid WiFi on same ESP32 (interference) |
| Left vs right hand model differences | Train separate models per hand; collect equal amounts of data for both; validate independently |
| ESP32 I2C lockup (rare MPU6050 issue) | Add I2C bus recovery in firmware (toggle SCL 9 times); use watchdog timer for auto-reset |
| Student soldering quality | Start with breadboard prototype; test thoroughly before soldering; use header pins for removable connections |
