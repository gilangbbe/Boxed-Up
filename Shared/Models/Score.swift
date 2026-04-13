//
//  Score.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// Aggregate scoring data for a round or session.
struct Score: Codable {
    var correctCount: Int = 0
    var totalCount: Int = 0
    var totalPoints: Double = 0
    var totalReactionTime: TimeInterval = 0
    var totalConfidence: Double = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0

    var accuracy: Double {
        totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0
    }

    var avgReactionTime: TimeInterval {
        totalCount > 0 ? totalReactionTime / Double(totalCount) : 0
    }

    var avgConfidence: Double {
        totalCount > 0 ? totalConfidence / Double(totalCount) : 0
    }

    mutating func recordPunch(correct: Bool, points: Double, reactionTime: TimeInterval, confidence: Double) {
        totalCount += 1
        totalReactionTime += reactionTime
        totalConfidence += confidence
        if correct {
            correctCount += 1
            totalPoints += points
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        } else {
            currentStreak = 0
        }
    }
}
