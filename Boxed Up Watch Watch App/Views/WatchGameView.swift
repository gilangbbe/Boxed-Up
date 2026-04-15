//
//  WatchGameView.swift
//  Boxed Up Watch Watch App
//
//  Created on 13/04/26.
//

import SwiftUI
import WatchKit

struct WatchGameView: View {
    var currentAction: PunchType?
    var lastPunchCorrect: Bool?

    var body: some View {
        VStack(spacing: 8) {
            if let punch = currentAction {
                Image(systemName: "figure.boxing")
                    .font(.system(size: 30))
                    .foregroundStyle(.red)

                Text(punch.rawValue.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.red)
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
