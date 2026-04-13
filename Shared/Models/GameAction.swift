//
//  GameAction.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// Actions the virtual sparring partner can display.
/// - Attack actions: opponent attacks the player, who must counter with the correct punch.
/// - Opening actions: opponent leaves a gap, player must exploit with the correct punch.
enum GameAction: String, Codable, CaseIterable {
    // Opponent attacks — player must counter
    case attackJab
    case attackHook
    case attackUppercut

    // Opponent leaves an opening — player must exploit
    case openHead
    case openBody
    case openSide

    var isAttack: Bool {
        switch self {
        case .attackJab, .attackHook, .attackUppercut: return true
        case .openHead, .openBody, .openSide: return false
        }
    }

    var displayLabel: String {
        switch self {
        case .attackJab:      return "ATTACK — JAB"
        case .attackHook:     return "ATTACK — HOOK"
        case .attackUppercut: return "ATTACK — UPPERCUT"
        case .openHead:       return "OPENING — HEAD"
        case .openBody:       return "OPENING — BODY"
        case .openSide:       return "OPENING — SIDE"
        }
    }
}
