//
//  ScoringEngine.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// Calculates points for each punch based on correctness, reaction time, and ML confidence.
///
/// Formula: `basePoints × reactionMultiplier × confidenceMultiplier`
/// - Base: 100 for correct, 0 for wrong
/// - Reaction: 2.0× (<0.3s), 1.5× (<0.5s), 1.0× (<1.0s), 0.5× (≥1.0s)
/// - Confidence: linear scale from ML model output (0.0–1.0)
enum ScoringEngine {

    static let basePoints: Double = 100

    static func reactionMultiplier(for reactionTime: TimeInterval) -> Double {
        switch reactionTime {
        case ..<0.3: return 2.0
        case ..<0.5: return 1.5
        case ..<1.0: return 1.0
        default:     return 0.5
        }
    }

    static func calculatePoints(correct: Bool, reactionTime: TimeInterval, confidence: Double) -> Double {
        guard correct else { return 0 }
        return basePoints * reactionMultiplier(for: reactionTime) * confidence
    }

    static func streakBonus(streak: Int) -> Double {
        guard streak >= 3 else { return 0 }
        return Double(streak) * 10
    }
}
