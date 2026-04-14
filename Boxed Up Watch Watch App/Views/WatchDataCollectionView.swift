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

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.boxing")
                .font(.title2)
                .foregroundStyle(.blue)

            Text("Data Collection")
                .font(.headline)

            if isRecording {
                VStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 16, height: 16)

                    Text("Recording...")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)

                    Text("Throw now!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Ready")
                    .font(.subheadline)
                    .foregroundStyle(.green)

                Text("Waiting for iPhone…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
