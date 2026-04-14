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

            // Watch connection status
            HStack {
                Image(systemName: viewModel.sessionManager.isWatchReachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                    .foregroundStyle(viewModel.sessionManager.isWatchReachable ? .green : .red)
                Text(viewModel.sessionManager.isWatchReachable ? "Watch Connected" : "Watch Not Connected")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.sessionManager.isWatchReachable ? .green : .red)
            }

            Button {
                viewModel.startRound()
            } label: {
                Text("Start Round")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.sessionManager.isWatchReachable ? .red : .gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!viewModel.sessionManager.isWatchReachable)
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

            Spacer()
        }
        .padding()
    }
}
