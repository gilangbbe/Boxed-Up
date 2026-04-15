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
    @State private var workoutManager = WorkoutSessionManager()

    enum WatchAppMode { case home, game, dataCollection }
    @State private var appMode: WatchAppMode = .home
    @State private var currentAction: PunchType?
    @State private var lastPunchCorrect: Bool?
    @State private var isDataCollectionRecording = false

    var body: some Scene {
        WindowGroup {
            Group {
                switch appMode {
                case .home:
                    WatchHomeView(sessionManager: sessionManager)
                case .game:
                    WatchGameView(currentAction: currentAction, lastPunchCorrect: lastPunchCorrect)
                case .dataCollection:
                    WatchDataCollectionView(isRecording: isDataCollectionRecording)
                }
            } 
            .onAppear {
                setupWatch()
            }
        }
    }

    private func setupWatch() {
        let streamer = MotionStreamer(sessionManager: sessionManager)
        motionStreamer = streamer

        sessionManager.activate()
        workoutManager.requestAuthorization()

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
                // Update recording indicator for data collection mode
                if appMode == .dataCollection {
                    isDataCollectionRecording = start
                    WKInterfaceDevice.current().play(start ? .start : .stop)
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
                appMode = started ? .game : .home
                if started {
                    workoutManager.startSession()
                } else {
                    currentAction = nil
                    lastPunchCorrect = nil
                    workoutManager.endSession()
                }
            }
        }

        // Handle data collection mode
        sessionManager.onDataCollectionMode = { active in
            Task { @MainActor in
                appMode = active ? .dataCollection : .home
                isDataCollectionRecording = false
                if active {
                    workoutManager.startSession()
                } else {
                    workoutManager.endSession()
                }
            }
        }

        // Handle iPhone disconnect — pause motion capture to conserve resources
        sessionManager.onReachabilityChanged = { reachable in
            Task { @MainActor in
                if !reachable && motionManager.isCapturing {
                    motionManager.stopCapture()
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }
}
