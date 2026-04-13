//
//  CounterMapping.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// Maps each GameAction to the correct PunchType counter.
///
/// Each punch type is the correct answer exactly 2 times
/// (once as a counter to an attack, once as an exploit of an opening).
///
/// Attack counters:
///   .attackJab       → Uppercut  (duck under the jab, counter upward)
///   .attackHook      → Jab       (pull back, straight counter)
///   .attackUppercut  → Hook      (pivot aside, swing counter)
///
/// Opening exploits:
///   .openHead        → Jab       (fastest strike to exposed head)
///   .openBody        → Uppercut  (strike exposed body from below)
///   .openSide        → Hook      (swing into the exposed flank)
enum CounterMapping {
    static func correctPunch(for action: GameAction) -> PunchType {
        switch action {
        case .attackJab:      return .uppercut
        case .attackHook:     return .jab
        case .attackUppercut: return .hook
        case .openHead:       return .jab
        case .openBody:       return .uppercut
        case .openSide:       return .hook
        }
    }

    static func isCorrect(punch: PunchType, for action: GameAction) -> Bool {
        punch == correctPunch(for: action)
    }
}
