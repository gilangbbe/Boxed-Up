//
//  Boxed_Up_WatchApp.swift
//  Boxed Up Watch Watch App
//
//  Created by Gilang Banyu Biru Erassunu on 13/04/26.
//

import SwiftUI
import WatchKit

@main
struct Boxed_Up_Watch_Watch_AppApp: App {
    @State private var sessionManager = WatchSessionManager()
    @State private var motionManager = WatchMotionManager()
    @State private var motionStreamer: MotionStreamer?

    @State private var isRoundActive = false
    @State private var currentAction: GameAction?
    @State private var lastPunchCorrect: Bool?

    var body: some Scene {
        WindowGroup {
            if isRoundActive {
                WatchGameView(currentAction: currentAction, lastPunchCorrect: lastPunchCorrect)
            } else {
                WatchHomeView(sessionManager: sessionManager)
            }
        }
        .onAppear {
            setupWatch()
        }
    }

    private func setupWatch() {
        let streamer = MotionStreamer(sessionManager: sessionManager)
        motionStreamer = streamer

        sessionManager.activate()

        // Forward motion samples to streamer
        motionManager.onSample = { sample in
            streamer.addSample(sample)
        }

        // Handle capture start/stop from iPhone
        sessionManager.onCaptureControl = { start in
            Task { @MainActor in
                if start {
                    motionManager.startCapture()
                    sessionManager.send(.motionStarted)
                } else {
                    motionManager.stopCapture()
                    streamer.flush()
                    sessionManager.send(.motionStopped)
                }
            }
        }

        // Handle game state updates
        sessionManager.onGameState = { action in
            Task { @MainActor in
                currentAction = action
            }
        }

        // Handle punch detection haptics
        sessionManager.onPunchDetected = { _, correct in
            Task { @MainActor in
                lastPunchCorrect = correct
                WKInterfaceDevice.current().play(correct ? .success : .failure)
            }
        }

        // Handle round lifecycle
        sessionManager.onRoundLifecycle = { started in
            Task { @MainActor in
                isRoundActive = started
                if !started {
                    currentAction = nil
                    lastPunchCorrect = nil
                }
            }
        }
    }
}
