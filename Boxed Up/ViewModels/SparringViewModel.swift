//
//  SparringViewModel.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// Orchestrates the full game loop on iPhone:
/// displays actions, receives motion from Watch/Glove, classifies punches, scores, and sends feedback.
@Observable
class SparringViewModel {

    // MARK: - Nested Types

    enum GameMode: String, CaseIterable {
        case singleHand = "Watch Only"
        case glove = "Glove Only"
        case combo = "Combo"
    }

    enum GamePhase {
        case home
        case playing
        case results
    }

    // MARK: - Dependencies

    var roundManager = RoundManager()
    let motionBuffer = MotionDataBuffer()       // Left hand — Apple Watch
    let gloveBuffer = MotionDataBuffer()        // Right hand — Smart Glove
    let comboManager = ComboManager()
    let sessionManager: PhoneSessionManager
    let gloveManager: GloveSessionManager
    let fitnessStore: FitnessStore
    private let classifier: PunchClassifierService?
    private let mlQueue = DispatchQueue(label: "com.boxedup.ml", qos: .userInitiated)

    // MARK: - State

    var gameMode: GameMode = .singleHand
    private(set) var score = Score()
    private(set) var lastPunchResult: PunchResult?
    private(set) var lastPunchCorrect: Bool?
    private(set) var isWaitingForPunch: Bool = false
    private(set) var gamePhase: GamePhase = .home
    private(set) var isDisconnected: Bool = false
    private(set) var reactionTimeRemaining: Double = 1.0
    private(set) var comboStepResults: [Bool?] = []
    private(set) var isShowingComboPreview: Bool = false

    private var currentComboIndex: Int = 0
    private let combosPerRound = 3
    private var comboStepStartTime: Date?
    private var timeoutTask: Task<Void, Never>?

    // MARK: - Fitness Tracking

    private var roundStartTime: Date?
    private(set) var lastRoundDuration: TimeInterval = 0
    private(set) var lastRoundCalories: Double = 0

    // MARK: - Combo Progress Accessors

    var comboNumber: Int { currentComboIndex + 1 }
    var totalCombos: Int { combosPerRound }

    // MARK: - Init

    init(sessionManager: PhoneSessionManager, gloveManager: GloveSessionManager, fitnessStore: FitnessStore) {
        self.sessionManager = sessionManager
        self.gloveManager = gloveManager
        self.fitnessStore = fitnessStore
        self.classifier = PunchClassifierService()
        if classifier == nil {
            print("[SparringVM] Warning: ML models not loaded — falling back to random classifier")
        }
        setupMotionCallback()
        setupDisconnectHandling()
    }

    // MARK: - Glove Scanning

    func startGloveScanning() { gloveManager.startScanning() }
    func stopGloveScanning()  { gloveManager.stopScanning() }

    // MARK: - Game Flow

    func startRound() {
        score = Score()
        lastPunchResult = nil
        lastPunchCorrect = nil
        isDisconnected = false
        gamePhase = .playing
        isWaitingForPunch = true
        reactionTimeRemaining = 1.0
        roundStartTime = Date()
        motionBuffer.reset()
        gloveBuffer.reset()
        classifier?.resetState()

        sessionManager.send(.roundStart)
        sessionManager.send(.startCapture)

        switch gameMode {
        case .singleHand:
            roundManager.startRound()
            if let punch = roundManager.currentAction {
                sessionManager.send(.gameState(punch))
            }
            startReactionTimeout()
        case .glove:
            roundManager.startRound()
            gloveManager.startScanning()
            gloveManager.startCapture()   // tell ESP32 to start streaming
            setupGloveCallback()
            if let punch = roundManager.currentAction {
                sessionManager.send(.gameState(punch))
            }
            startReactionTimeout()
        case .combo:
            currentComboIndex = 0
            comboManager.generateNewCombo()
            comboStepResults = Array(repeating: nil, count: comboManager.stepsPerCombo)
            gloveManager.startScanning()
            gloveManager.startCapture()   // tell ESP32 to start streaming
            setupGloveCallback()
            beginComboWithPreview()
        }
    }

    func endRound() {
        timeoutTask?.cancel()
        timeoutTask = nil
        isWaitingForPunch = false
        isShowingComboPreview = false

        // Save fitness record before transitioning to results
        let duration = roundStartTime.map { Date().timeIntervalSince($0) } ?? 0
        lastRoundDuration = duration
        lastRoundCalories = fitnessStore.estimateCalories(duration: duration)
        roundStartTime = nil
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            duration: duration,
            punchCount: score.totalCount,
            correctCount: score.correctCount,
            points: score.totalPoints,
            grade: gradeString(for: score),
            gameMode: gameMode.rawValue,
            calories: lastRoundCalories
        )
        fitnessStore.addSession(record)

        gamePhase = .results
        comboStepStartTime = nil

//        SoundManager.playRoundComplete()

        sessionManager.send(.stopCapture)
        sessionManager.send(.roundEnd)
        motionBuffer.reset()
        gloveBuffer.reset()

        switch gameMode {
        case .singleHand:
            roundManager.endRound()
        case .glove:
            roundManager.endRound()
            gloveManager.stopCapture()
            gloveManager.onMotionData = nil
        case .combo:
            roundManager.endRound()
            gloveManager.stopCapture()
            gloveManager.onMotionData = nil
        }
    }

    func returnToHome() {
        gamePhase = .home
        lastPunchResult = nil
        lastPunchCorrect = nil
    }

    // MARK: - Single Hand Punch Processing (Watch)

    func processPunch() {
        guard isWaitingForPunch, gameMode == .singleHand else { return }
        guard let expectedPunch = roundManager.currentAction,
              let reactionTime = roundManager.elapsedReactionTime,
              let window = motionBuffer.captureWindow() else { return }

        isWaitingForPunch = false
        timeoutTask?.cancel()
        timeoutTask = nil

        let classifiedPunch = classifyPunchSingleHand(from: window)
        let correct = classifiedPunch.punchType == expectedPunch

        recordResult(punchType: classifiedPunch.punchType, confidence: classifiedPunch.confidence,
                     reactionTime: reactionTime, correct: correct)
        sessionManager.send(.punchDetected(classifiedPunch.punchType, correct: correct))

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            self.advanceAction()
        }
    }

    // MARK: - Single Hand Punch Processing (Glove)

    private func processGlovePunch() {
        guard isWaitingForPunch, gameMode == .glove else { return }
        guard let expectedPunch = roundManager.currentAction,
              let reactionTime = roundManager.elapsedReactionTime else { return }
        guard let samples = gloveBuffer.captureWindow() else { return }

        isWaitingForPunch = false
        timeoutTask?.cancel()
        timeoutTask = nil

        let classified = classifyPunch(from: samples, hand: .right)
        let correct = classified.punchType == expectedPunch

        recordResult(punchType: classified.punchType, confidence: classified.confidence,
                     reactionTime: reactionTime, correct: correct)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            self.advanceAction()
        }
    }

    // MARK: - Combo Step Processing

    /// Mirrors processPunch() / processGlovePunch(): pulls a full 50-sample window
    /// from the correct buffer via captureWindow(). Returns nil (no side-effects)
    /// if fewer than 50 samples are available yet, so the motion callback will
    /// retry naturally on the next batch until the window is full.
    private func processComboStep(hand: HandSide) {
        guard isWaitingForPunch else { return }
        guard let step = comboManager.currentStep, step.hand == hand else { return }

        let buffer = hand == .left ? motionBuffer : gloveBuffer
        guard let samples = buffer.captureWindow() else { return }

        let reactionTime = comboStepStartTime.map { Date().timeIntervalSince($0) }
                        ?? roundManager.config.effectiveReactionWindow

        isWaitingForPunch = false
        timeoutTask?.cancel()
        timeoutTask = nil

        let classified = classifyPunch(from: samples, hand: hand)
        let correct = classified.punchType == step.punch

        comboStepResults[comboManager.currentStepIndex] = correct
        comboManager.advanceStep()

        recordResult(punchType: classified.punchType, confidence: classified.confidence,
                     reactionTime: reactionTime, correct: correct)

        // Only send Watch haptic for left-hand punches
        if hand == .left {
            sessionManager.send(.punchDetected(classified.punchType, correct: correct))
        }

        if comboManager.isComboComplete {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.0))
                self.advanceCombo()
            }
        } else {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                self.startNextComboStep()
            }
        }
    }

    // MARK: - Reaction Timeout

    private func startReactionTimeout() {
        timeoutTask?.cancel()
        reactionTimeRemaining = 1.0
        let window = roundManager.config.effectiveReactionWindow
        let tickInterval: TimeInterval = 0.05  // 20 fps countdown

        timeoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startDate = Date()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickInterval))
                guard !Task.isCancelled else { return }

                let elapsed = Date().timeIntervalSince(startDate)
                let remaining = max(0, 1.0 - elapsed / window)
                self.reactionTimeRemaining = remaining

                if remaining <= 0 {
                    self.handleTimeout()
                    return
                }
            }
        }
    }

    private func handleTimeout() {
        guard isWaitingForPunch else { return }
        isWaitingForPunch = false

        let reactionTime: TimeInterval
        if gameMode == .combo {
            reactionTime = comboStepStartTime.map { Date().timeIntervalSince($0) }
                        ?? roundManager.config.effectiveReactionWindow
        } else {
            reactionTime = roundManager.elapsedReactionTime ?? roundManager.config.effectiveReactionWindow
        }

        score.recordPunch(correct: false, points: 0, reactionTime: reactionTime, confidence: 0)
        lastPunchResult = nil
        lastPunchCorrect = false
//        SoundManager.playTimeout()

        if gameMode == .combo {
            let stepIndex = comboManager.currentStepIndex
            if stepIndex < comboStepResults.count {
                comboStepResults[stepIndex] = false
            }
            comboManager.advanceStep()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                if self.comboManager.isComboComplete {
                    self.advanceCombo()
                } else {
                    self.startNextComboStep()
                }
            }
        } else {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                self.advanceAction()
            }
        }
    }

    // MARK: - Private

    func setupMotionCallback() {
        sessionManager.onMotionData = { [weak self] samples in
            guard let self else { return }
            Task { @MainActor in
                self.motionBuffer.append(samples)
                guard self.isWaitingForPunch else { return }

                // Glove-only mode: Watch motion is not used
                guard self.gameMode != .glove else { return }
                // Combo mode: Watch only handles left-hand steps
                if self.gameMode == .combo {
                    guard self.comboManager.currentStep?.hand == .left else { return }
                }

                if let classifier = self.classifier {
                    let allSamples = self.motionBuffer.allSamples
                    let mode = self.gameMode
                    self.mlQueue.async { [weak self] in
                        guard let self else { return }
                        let detection: (isPunch: Bool, confidence: Double) = mode == .combo
                            ? classifier.detectPunch(from: allSamples, hand: .left)
                            : classifier.detectPunch(from: allSamples)

                        if detection.isPunch && detection.confidence > 0.9 {
                            Task { @MainActor in
                                if self.gameMode == .combo {
                                    self.processComboStep(hand: .left)
                                } else {
                                    self.processPunch()
                                }
                            }
                        }
                    }
                } else {
                    // Fallback: threshold-based detection
                    if self.motionBuffer.checkForPunch() {
                        if self.gameMode == .combo {
                            self.processComboStep(hand: .left)
                        } else {
                            self.processPunch()
                        }
                    }
                }
            }
        }
    }

    private func setupGloveCallback() {
        gloveManager.onMotionData = { [weak self] samples in
            guard let self else { return }
            Task { @MainActor in
                self.gloveBuffer.append(samples)
                guard self.isWaitingForPunch else { return }

                switch self.gameMode {
                case .glove:
                    if let classifier = self.classifier {
                        let allSamples = self.gloveBuffer.allSamples
                        self.mlQueue.async { [weak self] in
                            guard let self else { return }
                            let detection = classifier.detectPunch(from: allSamples, hand: .right)
                            if detection.isPunch && detection.confidence > 0.6 {
                                Task { @MainActor in
                                    self.processGlovePunch()
                                }
                            }
                        }
                    } else {
                        if self.gloveBuffer.checkForPunch() {
                            self.processGlovePunch()
                        }
                    }

                case .combo:
                    guard self.comboManager.currentStep?.hand == .right else { return }
                    if let classifier = self.classifier {
                        let allSamples = self.gloveBuffer.allSamples
                        self.mlQueue.async { [weak self] in
                            guard let self else { return }
                            let detection = classifier.detectPunch(from: allSamples, hand: .right)
                            if detection.isPunch && detection.confidence > 0.9 {
                                Task { @MainActor in
                                    self.processComboStep(hand: .right)
                                }
                            }
                        }
                    } else {
                        if self.gloveBuffer.checkForPunch() {
                            self.processComboStep(hand: .right)
                        }
                    }

                case .singleHand:
                    break  // Glove not used in singleHand mode
                }
            }
        }
    }

    private func setupDisconnectHandling() {
        sessionManager.onReachabilityChanged = { [weak self] reachable in
            guard let self else { return }
            Task { @MainActor in
                if self.gamePhase == .playing {
                    if !reachable {
                        self.pauseForDisconnect()
                    } else if self.isDisconnected {
                        self.resumeAfterReconnect()
                    }
                }
            }
        }
    }

    private func pauseForDisconnect() {
        isDisconnected = true
        isWaitingForPunch = false
        timeoutTask?.cancel()
        timeoutTask = nil
        roundManager.pauseReactionTimer()
    }

    private func resumeAfterReconnect() {
        isDisconnected = false
        motionBuffer.reset()
        gloveBuffer.reset()

        sessionManager.send(.roundStart)
        sessionManager.send(.startCapture)

        if gameMode == .singleHand || gameMode == .glove {
            if let punch = roundManager.currentAction {
                sessionManager.send(.gameState(punch))
            }
            roundManager.resumeReactionTimer()
        } else {
            comboStepStartTime = Date()
            if let step = comboManager.currentStep, step.hand == .left {
                sessionManager.send(.gameState(step.punch))
            }
        }

        isWaitingForPunch = true
        startReactionTimeout()
    }

    private func advanceAction() {
        motionBuffer.reset()
        gloveBuffer.reset()
        classifier?.resetDetectorState()
        lastPunchResult = nil
        lastPunchCorrect = nil

        roundManager.advanceToNextAction()

        if roundManager.isRoundComplete {
            endRound()
        } else {
            isWaitingForPunch = true
            if let punch = roundManager.currentAction {
                sessionManager.send(.gameState(punch))
            }
            startReactionTimeout()
        }
    }

    // MARK: - Advance: Combo

    private func beginComboWithPreview() {
        timeoutTask?.cancel()
        timeoutTask = nil
        isWaitingForPunch = false
        isShowingComboPreview = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(3.0))
            guard self.gamePhase == .playing else { return }
            self.isShowingComboPreview = false
            self.startFirstComboStep()
        }
    }

    private func startFirstComboStep() {
        motionBuffer.reset()
        gloveBuffer.reset()
        classifier?.resetDetectorState()
        lastPunchResult = nil
        lastPunchCorrect = nil
        comboStepStartTime = Date()
        isWaitingForPunch = true
        if let step = comboManager.currentStep, step.hand == .left {
            sessionManager.send(.gameState(step.punch))
        }
        startReactionTimeout()
    }

    private func startNextComboStep() {
        motionBuffer.reset()
        gloveBuffer.reset()
        classifier?.resetDetectorState()
        lastPunchResult = nil
        lastPunchCorrect = nil
        comboStepStartTime = Date()
        isWaitingForPunch = true

        if let step = comboManager.currentStep, step.hand == .left {
            sessionManager.send(.gameState(step.punch))
        }
        startReactionTimeout()
    }

    private func advanceCombo() {
        currentComboIndex += 1
        lastPunchResult = nil
        lastPunchCorrect = nil

        if currentComboIndex >= combosPerRound {
            endRound()
            return
        }

        comboManager.generateNewCombo()
        comboStepResults = Array(repeating: nil, count: comboManager.stepsPerCombo)
        motionBuffer.reset()
        gloveBuffer.reset()
        classifier?.resetDetectorState()
        beginComboWithPreview()
    }

    // MARK: - Helpers

    private func recordResult(punchType: PunchType, confidence: Double,
                               reactionTime: TimeInterval, correct: Bool) {
        let result = PunchResult(punchType: punchType, confidence: confidence, reactionTime: reactionTime)
        let points = ScoringEngine.calculatePoints(correct: correct, reactionTime: reactionTime, confidence: confidence)
        score.recordPunch(correct: correct,
                          points: points + ScoringEngine.streakBonus(streak: score.currentStreak),
                          reactionTime: reactionTime,
                          confidence: confidence)
        lastPunchResult = result
        lastPunchCorrect = correct
//        SoundManager.playPunchDetected()
//        if correct { SoundManager.playCorrect() } else { SoundManager.playWrong() }
    }

    private func classifyPunchSingleHand(from samples: [MotionSample]) -> (punchType: PunchType, confidence: Double) {
        if let classifier { return classifier.classifyPunch(from: samples) }
        return (PunchType.allCases.randomElement()!, Double.random(in: 0.5...1.0))
    }

    private func classifyPunch(from samples: [MotionSample], hand: HandSide) -> (punchType: PunchType, confidence: Double) {
        if let classifier { return classifier.classifyPunch(from: samples, hand: hand) }
        return (PunchType.allCases.randomElement()!, Double.random(in: 0.5...1.0))
    }

    /// Derives the performance grade from a completed Score, mirroring ResultsView logic.
    private func gradeString(for s: Score) -> String {
        let a = s.totalCount > 0 ? s.accuracy : 0
        let t = s.avgReactionTime
        if a >= 0.9 && t < 0.4 { return "S" }
        if a >= 0.8             { return "A" }
        if a >= 0.65            { return "B" }
        if a >= 0.5             { return "C" }
        return "D"
    }
}
