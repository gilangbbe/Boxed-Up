//
//  MotionDataBuffer.swift
//  Boxed Up (iOS)
//
//  Created on 13/04/26.
//

import Foundation

/// Sliding window buffer for motion samples received from Apple Watch.
/// Used to accumulate samples for ML classification when a punch is detected.
@Observable
class MotionDataBuffer {

    /// Number of samples in the classification window (1 sec at 50 Hz).
    static let windowSize = 50

    /// Acceleration magnitude threshold (in g) to detect punch onset.
    static let punchThreshold: Double = 1.5

    private(set) var samples: [MotionSample] = []
    private(set) var isPunchDetected: Bool = false

    /// Read-only access to the full sample buffer for ML detection.
    var allSamples: [MotionSample] { samples }

    /// Adds new samples to the buffer. Trims to keep only the latest `windowSize` samples.
    func append(_ newSamples: [MotionSample]) {
        samples.append(contentsOf: newSamples)

        // Keep buffer at max 2× window size to avoid memory growth
        let maxBuffer = Self.windowSize * 2
        if samples.count > maxBuffer {
            samples.removeFirst(samples.count - maxBuffer)
        }
    }

    /// Checks the latest samples for a punch onset (acceleration spike above threshold).
    func checkForPunch() -> Bool {
        guard let latest = samples.last else { return false }
        return latest.accelerationMagnitude > Self.punchThreshold
    }

    /// Freezes and returns the current window for ML classification.
    /// Returns nil if not enough samples are available.
    func captureWindow() -> [MotionSample]? {
        guard samples.count >= Self.windowSize else { return nil }
        return Array(samples.suffix(Self.windowSize))
    }

    /// Resets the buffer for the next punch detection cycle.
    func reset() {
        samples.removeAll()
        isPunchDetected = false
    }

    /// Clears old samples but keeps the buffer active.
    func clearOldSamples() {
        if samples.count > Self.windowSize {
            samples = Array(samples.suffix(Self.windowSize))
        }
    }
}
