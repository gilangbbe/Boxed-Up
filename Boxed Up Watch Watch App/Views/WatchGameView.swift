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
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 6) {
                if let punch = currentAction {
                    Text(punch.rawValue.uppercased())
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(1.5)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal:   .opacity
                        ))
                        .animation(.spring(duration: 0.25), value: punch.rawValue)

                    if let correct = lastPunchCorrect {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(correct ? .green : .red)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: 8, height: 8)
                    }
                } else {
                    Text("GET READY")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(white: 0.45))
                        .tracking(1.5)
                }
            }
        }
    }
}
