//
//  WatchDataCollectionView.swift
//  Boxed Up Watch Watch App
//
//  Created on 14/04/26.
//

import SwiftUI

/// Minimal Watch display during data collection mode.
struct WatchDataCollectionView: View {
    let isRecording: Bool
    @State private var recordPulse = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 8) {
                Text("DATA COLLECTION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(white: 0.40))
                    .tracking(1.5)

                if isRecording {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(recordPulse ? 0.25 : 0.08))
                            .frame(width: 60, height: 60)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: recordPulse)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 14, height: 14)
                    }
                    .onAppear { recordPulse = true }
                    .onDisappear { recordPulse = false }

                    Text("RECORDING")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red)
                        .tracking(1)

                    Text("Throw now!")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.50))
                } else {
                    Image(systemName: "record.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(white: 0.35))

                    Text("READY")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.green)
                        .tracking(1)

                    Text("Waiting for iPhone")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.38))
                }
            }
        }
    }
}
