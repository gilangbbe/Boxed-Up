//
//  WatchMotionManager.swift
//  Boxed Up Watch Watch App
//
//  Created on 13/04/26.
//

import Foundation
import CoreMotion

/// Manages CoreMotion on Apple Watch. Captures device motion at 50 Hz.
@Observable
class WatchMotionManager {

    static let samplingRate: TimeInterval = 1.0 / 50.0  // 50 Hz

    private let motionManager = CMMotionManager()
    private(set) var isCapturing: Bool = false

    /// Called with each new motion sample.
    var onSample: ((MotionSample) -> Void)?

    func startCapture() {
        guard motionManager.isDeviceMotionAvailable, !isCapturing else { return }

        motionManager.deviceMotionUpdateInterval = Self.samplingRate
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion, error == nil else { return }

            let sample = MotionSample(
                timestamp: motion.timestamp,
                accX: motion.userAcceleration.x,
                accY: motion.userAcceleration.y,
                accZ: motion.userAcceleration.z,
                rotX: motion.rotationRate.x,
                rotY: motion.rotationRate.y,
                rotZ: motion.rotationRate.z
            )

            self.onSample?(sample)
        }

        isCapturing = true
    }

    func stopCapture() {
        motionManager.stopDeviceMotionUpdates()
        isCapturing = false
    }
}
