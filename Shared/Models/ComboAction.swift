//
//  ComboAction.swift
//  Boxed Up
//
//  Created on 24/04/26.
//

import Foundation

/// A single step in a combo: one specific hand + punch type.
struct ComboAction: Equatable {
    let hand: HandSide
    let punch: PunchType

    /// Short display label, e.g. "L-JAB" or "R-HOOK".
    var shortLabel: String {
        "\(hand == .left ? "L" : "R")-\(punch.rawValue.uppercased())"
    }
}
