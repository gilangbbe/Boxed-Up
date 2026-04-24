//
//  ComboManager.swift
//  Boxed Up
//
//  Created on 24/04/26.
//

import Foundation

/// Manages a single boxing combo: generates a sequence of hand+punch steps
/// and tracks execution progress through that sequence.
@Observable
class ComboManager {

    /// Number of punches per combo.
    let stepsPerCombo = 3

    private(set) var currentCombo: [ComboAction] = []
    private(set) var currentStepIndex: Int = 0

    // MARK: - Computed

    var currentStep: ComboAction? {
        guard currentStepIndex < currentCombo.count else { return nil }
        return currentCombo[currentStepIndex]
    }

    var isComboComplete: Bool {
        currentStepIndex >= currentCombo.count
    }

    // MARK: - Control

    /// Generate a fresh combo and reset the step index.
    func generateNewCombo() {
        currentCombo = makeCombo()
        currentStepIndex = 0
    }

    /// Advance past the current step. Call after validating (correct or miss).
    func advanceStep() {
        currentStepIndex += 1
    }

    func reset() {
        currentCombo = []
        currentStepIndex = 0
    }

    // MARK: - Private

    private func makeCombo() -> [ComboAction] {
        var combo: [ComboAction] = []
        var lastHand: HandSide?

        for _ in 0..<stepsPerCombo {
            // Favour hand alternation for realism, but occasionally allow same hand.
            let hand: HandSide
            if let last = lastHand, Bool.random() {
                // Alternate from last
                hand = last == .left ? .right : .left
            } else {
                hand = Bool.random() ? .left : .right
            }
            let punch = PunchType.allCases.randomElement()!
            combo.append(ComboAction(hand: hand, punch: punch))
            lastHand = hand
        }
        return combo
    }
}
