//
//  HomeView.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: SparringViewModel
    var onCollectData: () -> Void
    var onTestGlove: () -> Void

    private var canStartRound: Bool {
        switch viewModel.gameMode {
        case .singleHand:
            return viewModel.sessionManager.isWatchReachable
        case .glove:
            return viewModel.gloveManager.isGloveConnected
        case .combo:
            return viewModel.sessionManager.isWatchReachable && viewModel.gloveManager.isGloveConnected
        }
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "figure.boxing")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("Boxed Up")
                .font(.largeTitle.bold())

            Text("Motion Boxing Trainer")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            // Connection status
            VStack(spacing: 6) {
                if viewModel.gameMode != .glove {
                    HStack {
                        Image(systemName: viewModel.sessionManager.isWatchReachable
                              ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                            .foregroundStyle(viewModel.sessionManager.isWatchReachable ? .green : .red)
                        Text(viewModel.sessionManager.isWatchReachable ? "Watch Connected" : "Watch Not Connected")
                            .font(.subheadline)
                            .foregroundStyle(viewModel.sessionManager.isWatchReachable ? .green : .red)
                    }
                }
                if viewModel.gameMode == .combo || viewModel.gameMode == .glove {
                    HStack {
                        Image(systemName: viewModel.gloveManager.isGloveConnected
                              ? "hand.raised.fill" : "hand.raised.slash.fill")
                            .foregroundStyle(viewModel.gloveManager.isGloveConnected ? .green : .orange)
                        Text(viewModel.gloveManager.isGloveConnected ? "Glove Connected" : "Glove Not Connected")
                            .font(.subheadline)
                            .foregroundStyle(viewModel.gloveManager.isGloveConnected ? .green : .orange)
                    }
                }
            }

            // Game mode selection
            VStack(spacing: 8) {
                Text("Game Mode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Game Mode", selection: $viewModel.gameMode) {
                    ForEach(SparringViewModel.GameMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .onChange(of: viewModel.gameMode) { _, newMode in
                if newMode == .combo || newMode == .glove {
                    viewModel.startGloveScanning()
                } else {
                    viewModel.stopGloveScanning()
                }
            }

            // Difficulty selection
            VStack(spacing: 8) {
                Text("Difficulty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Difficulty", selection: $viewModel.roundManager.config.difficulty) {
                    ForEach(RoundManager.Config.Difficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.rawValue.capitalized).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            Button {
                viewModel.startRound()
            } label: {
                Text("Start Round")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canStartRound ? .red : .gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canStartRound)
            .padding(.horizontal)

            Button {
                onCollectData()
            } label: {
                Text("Collect Training Data")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Button {
                onTestGlove()
            } label: {
                Label("Test Smart Glove", systemImage: "hand.raised.fingers.spread")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange.opacity(0.1))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}
