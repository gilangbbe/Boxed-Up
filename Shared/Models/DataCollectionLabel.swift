//
//  DataCollectionLabel.swift
//  Boxed Up
//
//  Created on 14/04/26.
//

import Foundation

/// Labels used for recording training data sessions.
/// Punch types feed both the Punch Type Classifier and Punch Detector models.
/// The "other" label provides negative samples for the Punch Detector.
enum DataCollectionLabel: String, CaseIterable, Codable {
    case jab
    case hook
    case uppercut
    case other

    var displayName: String {
        switch self {
        case .jab: return "Jab"
        case .hook: return "Hook"
        case .uppercut: return "Uppercut"
        case .other: return "Other"
        }
    }

    var description: String {
        switch self {
        case .jab: return "Straight forward punch"
        case .hook: return "Sweeping side punch"
        case .uppercut: return "Upward rising punch"
        case .other: return "Non-punch activity (idle, walking, etc.)"
        }
    }

    var iconName: String {
        switch self {
        case .jab: return "arrow.right"
        case .hook: return "arrow.turn.right.down"
        case .uppercut: return "arrow.up"
        case .other: return "hand.raised.slash"
        }
    }
}
