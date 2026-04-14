//
//  SparringView.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import SwiftUI

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
            if let action = viewModel.roundManager.currentAction {
                VStack(spacing: 16) {
                    Image(systemName: action.isAttack ? "exclamationmark.shield.fill" : "scope")
                        .font(.system(size: 60))
                        .foregroundStyle(action.isAttack ? .red : .green)

                    Text(action.displayLabel)
                        .font(.title.bold())
                        .foregroundStyle(action.isAttack ? .red : .green)

                    Text("Throw: \(CounterMapping.correctPunch(for: action).rawValue.uppercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.roundManager.currentActionIndex)
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
            } else if viewModel.isWaitingForPunch {
                Text("Throw your punch!")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Round progress
            Text("Action \(viewModel.roundManager.currentActionIndex + 1) of \(viewModel.roundManager.config.actionsPerRound)")
                .font(.caption)
                .foregroundStyle(.secondary)
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
    }
}
