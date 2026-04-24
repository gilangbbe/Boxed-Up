//
//  SparringView.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import SwiftUI
import UIKit

struct SparringView: View {
    @Bindable var viewModel: SparringViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Score bar
            HStack {
                Label("\(viewModel.score.correctCount)/\(viewModel.score.totalCount)", systemImage: "target")
                Spacer()
                Label("×\(viewModel.score.currentStreak)", systemImage: "flame.fill")
                    .foregroundStyle(viewModel.score.currentStreak >= 3 ? .orange : .secondary)
                Spacer()
                Text("\(Int(viewModel.score.totalPoints)) pts")
                    .font(.headline.monospacedDigit())
            }
            .font(.subheadline)
            .padding(.horizontal)

            Spacer()

            // Current action display
            if viewModel.gameMode == .combo {
                // -- Combo mode --
                if !viewModel.comboManager.currentCombo.isEmpty {
                    VStack(spacing: 20) {
                        // Full combo sequence with step status
                        ComboProgressView(
                            combo: viewModel.comboManager.currentCombo,
                            currentStepIndex: viewModel.comboManager.currentStepIndex,
                            stepResults: viewModel.comboStepResults
                        )

                        // Large current step indicator
                        if let step = viewModel.comboManager.currentStep {
                            HStack(spacing: 12) {
                                Text(step.hand == .left ? "LEFT" : "RIGHT")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(step.hand == .left ? Color.blue : Color.red)
                                    .clipShape(Capsule())

                                Text(step.punch.rawValue.uppercased())
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(step.hand == .left ? .blue : .red)
                            }
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.2), value: viewModel.comboManager.currentStepIndex)
                        }
                    }
                }
            } else {
                // -- Single hand mode --
                if let punch = viewModel.roundManager.currentAction {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.boxing")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)

                        Text(punch.rawValue.uppercased())
                            .font(.largeTitle.bold())
                            .foregroundStyle(.red)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.roundManager.currentActionIndex)
                }
            }

            // Reaction timer bar (shared across modes)
            if viewModel.isWaitingForPunch {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.3))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(timerColor(for: viewModel.reactionTimeRemaining))
                            .frame(width: geo.size.width * viewModel.reactionTimeRemaining, height: 8)
                            .animation(.linear(duration: 0.05), value: viewModel.reactionTimeRemaining)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 32)
            }

            Spacer()

            // Punch feedback overlay
            if let result = viewModel.lastPunchResult, let correct = viewModel.lastPunchCorrect {
                VStack(spacing: 8) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(correct ? .green : .red)

                    Text("\(result.punchType.rawValue.uppercased()) — \(correct ? "Correct!" : "Wrong")")
                        .font(.headline)

                    Text(String(format: "%.2fs • %.0f%% confidence", result.reactionTime, result.confidence * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else if viewModel.lastPunchCorrect == false && viewModel.lastPunchResult == nil {
                // Timeout miss
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)

                    Text("TOO SLOW!")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                .transition(.opacity)
            } else if viewModel.isWaitingForPunch {
                Text("Throw your punch!")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Round progress
            if viewModel.gameMode == .combo {
                Text("Combo \(viewModel.comboNumber) of \(viewModel.totalCombos)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Action \(viewModel.roundManager.currentActionIndex + 1) of \(viewModel.roundManager.config.actionsPerRound)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .overlay {
            if viewModel.isDisconnected {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Image(systemName: "applewatch.slash")
                            .font(.system(size: 50))
                            .foregroundStyle(.red)

                        Text("Watch Disconnected")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("Game paused. Move closer to your iPhone to reconnect.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        ProgressView()
                            .tint(.white)
                            .padding(.top, 8)

                        Button {
                            viewModel.endRound()
                        } label: {
                            Text("End Round")
                                .font(.subheadline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(.red.opacity(0.3))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.top, 4)
                    }
                    .padding(32)
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func timerColor(for remaining: Double) -> Color {
        if remaining > 0.5 { return .green }
        if remaining > 0.25 { return .yellow }
        return .red
    }
}

// MARK: - Combo Progress View

private struct ComboProgressView: View {
    let combo: [ComboAction]
    let currentStepIndex: Int
    let stepResults: [Bool?]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(combo.enumerated()), id: \.offset) { index, action in
                stepView(for: action, at: index)

                if index < combo.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func stepView(for action: ComboAction, at index: Int) -> some View {
        let result = index < stepResults.count ? stepResults[index] : nil
        let isCurrent = index == currentStepIndex

        VStack(spacing: 6) {
            // Hand badge
            Text(action.hand == .left ? "L" : "R")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(action.hand == .left ? Color.blue : Color.red)
                .clipShape(Circle())

            // Punch type
            Text(action.punch.rawValue.uppercased())
                .font(.caption.bold())
                .foregroundStyle(isCurrent ? .primary : .secondary)

            // Status dot / result icon
            if let r = result {
                Image(systemName: r ? "checkmark" : "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(r ? .green : .red)
            } else {
                Circle()
                    .fill(isCurrent ? Color.orange : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(stepBackground(result: result, isCurrent: isCurrent))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func stepBackground(result: Bool?, isCurrent: Bool) -> Color {
        if let r = result {
            return (r ? Color.green : Color.red).opacity(0.1)
        }
        if isCurrent { return Color.orange.opacity(0.15) }
        return Color.gray.opacity(0.08)
    }
}
