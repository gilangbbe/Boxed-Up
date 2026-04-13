//
//  WatchGameView.swift
//  Boxed Up Watch Watch App
//
//  Created on 13/04/26.
//

import SwiftUI
import WatchKit

struct WatchGameView: View {
    var currentAction: GameAction?
    var lastPunchCorrect: Bool?

    var body: some View {
        VStack(spacing: 8) {
            if let action = currentAction {
                Image(systemName: action.isAttack ? "exclamationmark.shield.fill" : "scope")
                    .font(.system(size: 30))
                    .foregroundStyle(action.isAttack ? .red : .green)

                Text(action.displayLabel)
                    .font(.caption.bold())
                    .foregroundStyle(action.isAttack ? .red : .green)
                    .multilineTextAlignment(.center)
            } else {
                Text("Get Ready…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let correct = lastPunchCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(correct ? .green : .red)
            }
        }
    }
}
