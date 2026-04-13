//
//  PunchType.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// The three punch types the player can throw.
enum PunchType: String, Codable, CaseIterable {
    case jab
    case hook
    case uppercut
}
