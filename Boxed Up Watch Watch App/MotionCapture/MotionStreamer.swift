//
//  MotionStreamer.swift
//  Boxed Up Watch Watch App
//
//  Created on 13/04/26.
//

import Foundation
import WatchConnectivity

/// Batches motion samples and streams them to iPhone via WCSession.
/// Collects samples and sends in batches of `batchSize` to reduce message overhead.
@Observable
class MotionStreamer {

    /// Number of samples to batch before sending (5 samples at 50 Hz = every 100ms).
    static let batchSize = 5

    private var sampleBuffer: [MotionSample] = []
    private weak var sessionManager: WatchSessionManager?

    init(sessionManager: WatchSessionManager) {
        self.sessionManager = sessionManager
    }

    /// Adds a sample and sends a batch when the buffer is full.
    func addSample(_ sample: MotionSample) {
        sampleBuffer.append(sample)

        if sampleBuffer.count >= Self.batchSize {
            sendBatch()
        }
    }

    /// Flushes any remaining samples in the buffer.
    func flush() {
        guard !sampleBuffer.isEmpty else { return }
        sendBatch()
    }

    /// Resets the buffer.
    func reset() {
        sampleBuffer.removeAll()
    }

    private func sendBatch() {
        let batch = sampleBuffer
        sampleBuffer.removeAll()
        sessionManager?.send(.motionData(batch))
    }
}
