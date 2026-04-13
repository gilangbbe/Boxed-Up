//
//  PunchResult.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// The result of classifying a player's punch via the ML model.
struct PunchResult: Codable {
    let punchType: PunchType
    let confidence: Double      // 0.0–1.0 from Core ML
    let reactionTime: TimeInterval  // seconds since action was prompted
}
