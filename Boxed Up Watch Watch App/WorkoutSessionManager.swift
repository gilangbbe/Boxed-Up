//
//  WorkoutSessionManager.swift
//  Boxed Up Watch Watch App
//
//  Created on 14/04/26.
//

import Foundation
import HealthKit

/// Manages an HKWorkoutSession to keep the Watch app alive during gameplay and data collection.
/// Without this, watchOS will suspend the app after a few seconds of inactivity.
@Observable
class WorkoutSessionManager: NSObject {

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private(set) var isSessionActive: Bool = false

    // MARK: - Authorization

    func requestAuthorization() {
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error {
                print("[WorkoutSession] Authorization error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Session Lifecycle

    func startSession() {
        guard !isSessionActive else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .boxing
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()

            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            session.delegate = self
            builder.delegate = self

            self.workoutSession = session
            self.workoutBuilder = builder

            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { success, error in
                if let error {
                    print("[WorkoutSession] Begin collection error: \(error.localizedDescription)")
                }
            }
        } catch {
            print("[WorkoutSession] Failed to create session: \(error.localizedDescription)")
        }
    }

    func endSession() {
        guard isSessionActive else { return }

        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] success, error in
            self?.workoutBuilder?.finishWorkout { workout, error in
                if let error {
                    print("[WorkoutSession] Finish error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            isSessionActive = (toState == .running)
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        print("[WorkoutSession] Failed: \(error.localizedDescription)")
        Task { @MainActor in
            isSessionActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // No-op — we don't need workout events
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // No-op — we don't need to process collected health data
    }
}
