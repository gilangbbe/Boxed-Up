//
//  MotionSample.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// A single motion data point captured from Apple Watch sensors.
/// Contains 6 channels: user acceleration (x/y/z) and rotation rate (x/y/z).
struct MotionSample: Codable {
    let timestamp: TimeInterval
    let accX: Double
    let accY: Double
    let accZ: Double
    let rotX: Double
    let rotY: Double
    let rotZ: Double

    /// Magnitude of the acceleration vector.
    var accelerationMagnitude: Double {
        (accX * accX + accY * accY + accZ * accZ).squareRoot()
    }
}
