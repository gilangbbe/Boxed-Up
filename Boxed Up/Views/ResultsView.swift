//
//  ResultsView.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import SwiftUI

struct ResultsView: View {
    @Bindable var viewModel: SparringViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Round Complete!")
                .font(.largeTitle.bold())

            VStack(spacing: 16) {
                StatRow(label: "Score", value: "\(Int(viewModel.score.totalPoints))", icon: "star.fill", color: .yellow)
                StatRow(label: "Accuracy", value: String(format: "%.0f%%", viewModel.score.accuracy * 100), icon: "target", color: .blue)
                StatRow(label: "Avg Reaction", value: String(format: "%.2fs", viewModel.score.avgReactionTime), icon: "timer", color: .orange)
                StatRow(label: "Best Streak", value: "×\(viewModel.score.bestStreak)", icon: "flame.fill", color: .red)
                StatRow(label: "Correct", value: "\(viewModel.score.correctCount)/\(viewModel.score.totalCount)", icon: "checkmark.circle", color: .green)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            VStack(spacing: 12) {
                Button {
                    viewModel.startRound()
                } label: {
                    Text("Play Again")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    viewModel.returnToHome()
                } label: {
                    Text("Home")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 30)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
        }
    }
}
