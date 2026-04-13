//
//  Boxed_UpApp.swift
//  Boxed Up
//
//  Created by Gilang Banyu Biru Erassunu on 13/04/26.
//

import SwiftUI

@main
struct Boxed_UpApp: App {
    @State private var sessionManager = PhoneSessionManager()
    @State private var viewModel: SparringViewModel?

    var body: some Scene {
        WindowGroup {
            if let viewModel {
                switch viewModel.gamePhase {
                case .home:
                    HomeView(viewModel: viewModel)
                case .playing:
                    SparringView(viewModel: viewModel)
                case .results:
                    ResultsView(viewModel: viewModel)
                }
            } else {
                ProgressView("Connecting…")
                    .onAppear {
                        sessionManager.activate()
                        viewModel = SparringViewModel(sessionManager: sessionManager)
                    }
            }
        }
    }
}
