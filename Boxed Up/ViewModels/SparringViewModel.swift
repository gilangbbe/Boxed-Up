//
//  SparringViewModel.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// Orchestrates the full game loop on iPhone:
/// displays actions, receives motion from Watch, classifies punches, scores, and sends feedback.
@Observable
class SparringViewModel {

    // MARK: - Dependencies

    let roundManager = RoundManager()
    let motionBuffer = MotionDataBuffer()
    let sessionManager: PhoneSessionManager
    private let classifier: PunchClassifierService?
    private let mlQueue = DispatchQueue(label: "com.boxedup.ml", qos: .userInitiated)

    // MARK: - State

    private(set) var score = Score()
    private(set) var lastPunchResult: PunchResult?
    private(set) var lastPunchCorrect: Bool?
    private(set) var isWaitingForPunch: Bool = false
    private(set) var gamePhase: GamePhase = .home
    private(set) var isDisconnected: Bool = false
    private(set) var reactionTimeRemaining: Double = 1.0  // 0.0–1.0 fraction

    private var timeoutTask: Task<Void, Never>?

    enum GamePhase {
        case home
        case playing
        case results
    }

    // MARK: - Init

    init(sessionManager: PhoneSessionManager) {
        self.sessionManager = sessionManager
        self.classifier = PunchClassifierService()
        if classifier == nil {
            print("[SparringVM] Warning: ML models not loaded — falling back to random classifier")
        }
        setupMotionCallback()
        setupDisconnectHandling()
    }

    // MARK: - Game Flow

    func startRound() {
        score = Score()
        lastPunchResult = nil
        lastPunchCorrect = nil
        isDisconnected = false
        roundManager.startRound()
        gamePhase = .playing
        isWaitingForPunch = true
        reactionTimeRemaining = 1.0
        motionBuffer.reset()
        classifier?.resetState()

        sessionManager.send(.roundStart)
        sessionManager.send(.startCapture)

        if let action = roundManager.currentAction {
            sessionManager.send(.gameState(action))
        }

        startReactionTimeout()
    }

    func endRound() {
        timeoutTask?.cancel()
        timeoutTask = nil
        roundManager.endRound()
        isWaitingForPunch = false
        gamePhase = .results

        SoundManager.playRoundComplete()

        sessionManager.send(.stopCapture)
        sessionManager.send(.roundEnd)
        motionBuffer.reset()
    }

    func returnToHome() {
        gamePhase = .home
        lastPunchResult = nil
        lastPunchCorrect = nil
    }

    // MARK: - Punch Processing

    func processPunch() {
        guard isWaitingForPunch,
              let action = roundManager.currentAction,
              let reactionTime = roundManager.elapsedReactionTime,
              let window = motionBuffer.captureWindow() else { return }

        isWaitingForPunch = false
        timeoutTask?.cancel()
        timeoutTask = nil

        let classifiedPunch = classifyPunch(from: window)
        let correct = CounterMapping.isCorrect(punch: classifiedPunch.punchType, for: action)

        let result = PunchResult(
            punchType: classifiedPunch.punchType,
            confidence: classifiedPunch.confidence,
            reactionTime: reactionTime
        )

        let points = ScoringEngine.calculatePoints(
            correct: correct,
            reactionTime: reactionTime,
            confidence: classifiedPunch.confidence
        )

        score.recordPunch(
            correct: correct,
            points: points + ScoringEngine.streakBonus(streak: score.currentStreak),
            reactionTime: reactionTime,
            confidence: classifiedPunch.confidence
        )

        lastPunchResult = result
        lastPunchCorrect = correct

        // Sound + haptic feedback
        SoundManager.playPunchDetected()
        if correct {
            SoundManager.playCorrect()
        } else {
            SoundManager.playWrong()
        }

        // Send haptic feedback to Watch
        sessionManager.send(.punchDetected(classifiedPunch.punchType, correct: correct))

        // Advance to next action after a brief delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            self.advanceAction()
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

        // Record a miss — no punch thrown in time
        score.recordPunch(correct: false, points: 0, reactionTime: roundManager.config.effectiveReactionWindow, confidence: 0)

        lastPunchResult = nil
        lastPunchCorrect = false

        SoundManager.playTimeout()

        // Advance to next action after a brief delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            self.advanceAction()
        }
    }

    // MARK: - Private

    func setupMotionCallback() {
        sessionManager.onMotionData = { [weak self] samples in
            guard let self else { return }
            Task { @MainActor in
                self.motionBuffer.append(samples)
                guard self.isWaitingForPunch else { return }

                if let classifier = self.classifier {
                    // Run ML inference off the main thread
                    let allSamples = self.motionBuffer.allSamples
                    self.mlQueue.async { [weak self] in
                        let detection = classifier.detectPunch(from: allSamples)
                        if detection.isPunch && detection.confidence > 0.6 {
                            Task { @MainActor in
                                self?.processPunch()
                            }
                        }
                    }
                } else {
                    // Fallback: threshold-based detection
                    if self.motionBuffer.checkForPunch() {
                        self.processPunch()
                    }
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

        // Re-send current state to Watch
        sessionManager.send(.roundStart)
        sessionManager.send(.startCapture)
        if let action = roundManager.currentAction {
            sessionManager.send(.gameState(action))
        }

        roundManager.resumeReactionTimer()
        isWaitingForPunch = true
        startReactionTimeout()
    }

    private func advanceAction() {
        motionBuffer.clearOldSamples()
        lastPunchResult = nil
        lastPunchCorrect = nil

        roundManager.advanceToNextAction()

        if roundManager.isRoundComplete {
            endRound()
        } else {
            isWaitingForPunch = true
            if let action = roundManager.currentAction {
                sessionManager.send(.gameState(action))
            }
            startReactionTimeout()
        }
    }

    /// Classifies the punch type from the current motion buffer.
    private func classifyPunch(from samples: [MotionSample]) -> (punchType: PunchType, confidence: Double) {
        if let classifier {
            return classifier.classifyPunch(from: samples)
        }
        // Fallback if models not loaded
        let randomPunch = PunchType.allCases.randomElement()!
        return (randomPunch, Double.random(in: 0.5...1.0))
    }
}
