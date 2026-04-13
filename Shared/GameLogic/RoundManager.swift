//
//  RoundManager.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// Manages round state: generates action sequences, tracks timing, and controls round lifecycle.
@Observable
class RoundManager {

    // MARK: - Configuration

    struct Config {
        var actionsPerRound: Int = 10
        var actionInterval: TimeInterval = 2.5    // seconds between actions
        var reactionWindow: TimeInterval = 2.0    // max time to respond
        var difficulty: Difficulty = .normal

        enum Difficulty: String, CaseIterable {
            case easy       // slower intervals, longer reaction window
            case normal
            case hard       // faster intervals, shorter reaction window

            var intervalMultiplier: Double {
                switch self {
                case .easy:   return 1.3
                case .normal: return 1.0
                case .hard:   return 0.7
                }
            }

            var reactionMultiplier: Double {
                switch self {
                case .easy:   return 1.3
                case .normal: return 1.0
                case .hard:   return 0.7
                }
            }
        }

        var effectiveInterval: TimeInterval {
            actionInterval * difficulty.intervalMultiplier
        }

        var effectiveReactionWindow: TimeInterval {
            reactionWindow * difficulty.reactionMultiplier
        }
    }

    // MARK: - State

    var config = Config()
    private(set) var currentActionIndex: Int = 0
    private(set) var actions: [GameAction] = []
    private(set) var isRoundActive: Bool = false
    private(set) var actionStartTime: Date?

    var currentAction: GameAction? {
        guard isRoundActive, currentActionIndex < actions.count else { return nil }
        return actions[currentActionIndex]
    }

    var isRoundComplete: Bool {
        currentActionIndex >= actions.count
    }

    var elapsedReactionTime: TimeInterval? {
        guard let start = actionStartTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Round Control

    func startRound() {
        actions = generateActionSequence(count: config.actionsPerRound)
        currentActionIndex = 0
        isRoundActive = true
        actionStartTime = Date()
    }

    func advanceToNextAction() {
        currentActionIndex += 1
        if currentActionIndex < actions.count {
            actionStartTime = Date()
        } else {
            isRoundActive = false
            actionStartTime = nil
        }
    }

    func endRound() {
        isRoundActive = false
        actionStartTime = nil
    }

    // MARK: - Action Generation

    /// Generates a balanced, randomized sequence of GameActions.
    /// Ensures no more than 2 consecutive same-type actions (attack/opening).
    private func generateActionSequence(count: Int) -> [GameAction] {
        var sequence: [GameAction] = []
        let allActions = GameAction.allCases

        for _ in 0..<count {
            var candidate: GameAction
            repeat {
                candidate = allActions.randomElement()!
            } while wouldCreateBadRun(sequence: sequence, next: candidate)
            sequence.append(candidate)
        }

        return sequence
    }

    /// Prevents 3+ consecutive actions of the same category (attack/opening).
    private func wouldCreateBadRun(sequence: [GameAction], next: GameAction) -> Bool {
        guard sequence.count >= 2 else { return false }
        let last = sequence[sequence.count - 1]
        let secondLast = sequence[sequence.count - 2]
        return last.isAttack == next.isAttack && secondLast.isAttack == next.isAttack
    }
}
