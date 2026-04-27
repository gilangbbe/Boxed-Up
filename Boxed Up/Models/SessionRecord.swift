//
//  SessionRecord.swift
//  Boxed Up
//

import Foundation

/// Immutable record of a single completed boxing round.
struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval   // seconds
    let punchCount: Int          // total punches attempted
    let correctCount: Int        // correctly classified punches
    let points: Double
    let grade: String            // "S", "A", "B", "C", "D"
    let gameMode: String         // SparringViewModel.GameMode.rawValue
    let calories: Double         // estimated kcal burned
}
