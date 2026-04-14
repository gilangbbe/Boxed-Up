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
    @State private var dataCollectionViewModel: DataCollectionViewModel?
    @State private var isDataCollectionMode = false

    var body: some Scene {
        WindowGroup {
            if let viewModel {
                if isDataCollectionMode, let dcViewModel = dataCollectionViewModel {
                    DataCollectionView(viewModel: dcViewModel, onDone: exitDataCollection)
                } else {
                    switch viewModel.gamePhase {
                    case .home:
                        HomeView(viewModel: viewModel, onCollectData: enterDataCollection)
                    case .playing:
                        SparringView(viewModel: viewModel)
                    case .results:
                        ResultsView(viewModel: viewModel)
                    }
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

    private func enterDataCollection() {
        let dcViewModel = DataCollectionViewModel(sessionManager: sessionManager)
        dataCollectionViewModel = dcViewModel
        isDataCollectionMode = true
        sessionManager.send(.enterDataCollection)
    }

    private func exitDataCollection() {
        isDataCollectionMode = false
        sessionManager.send(.exitDataCollection)
        viewModel?.setupMotionCallback()
        dataCollectionViewModel = nil
    }
}
