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

    // MARK: - State

    private(set) var score = Score()
    private(set) var lastPunchResult: PunchResult?
    private(set) var lastPunchCorrect: Bool?
    private(set) var isWaitingForPunch: Bool = false
    private(set) var gamePhase: GamePhase = .home
    private(set) var isDisconnected: Bool = false

    enum GamePhase {
        case home
        case playing
        case results
    }

    // MARK: - Init

    init(sessionManager: PhoneSessionManager) {
        self.sessionManager = sessionManager
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
        motionBuffer.reset()

        sessionManager.send(.roundStart)
        sessionManager.send(.startCapture)

        if let action = roundManager.currentAction {
            sessionManager.send(.gameState(action))
        }
    }

    func endRound() {
        roundManager.endRound()
        isWaitingForPunch = false
        gamePhase = .results

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

        // TODO: Replace with actual Core ML classification (Phase 3)
        // For now, use a placeholder that picks a random punch type
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

        // Send haptic feedback to Watch
        sessionManager.send(.punchDetected(classifiedPunch.punchType, correct: correct))

        // Advance to next action after a brief delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            self.advanceAction()
        }
    }

    // MARK: - Private

    func setupMotionCallback() {
        sessionManager.onMotionData = { [weak self] samples in
            guard let self else { return }
            Task { @MainActor in
                self.motionBuffer.append(samples)
                if self.isWaitingForPunch && self.motionBuffer.checkForPunch() {
                    self.processPunch()
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
        }
    }

    /// Placeholder classifier — returns a random punch until the Core ML model is integrated.
    private func classifyPunch(from samples: [MotionSample]) -> (punchType: PunchType, confidence: Double) {
        // TODO: Replace with PunchClassifier Core ML inference
        let randomPunch = PunchType.allCases.randomElement()!
        return (randomPunch, Double.random(in: 0.5...1.0))
    }
}
