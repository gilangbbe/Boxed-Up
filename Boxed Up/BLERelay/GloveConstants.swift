//
//  GloveConstants.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation
import CoreBluetooth

/// BLE UUIDs and packet format constants for the ESP32 Smart Glove.
/// Must match the firmware definitions in BoxedUp.ino.
enum GloveConstants {
    // MARK: - BLE UUIDs
    static let serviceUUID       = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    static let motionCharUUID    = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")
    static let controlCharUUID   = CBUUID(string: "12345678-1234-1234-1234-123456789ABE")

    // MARK: - BLE Device Name
    static let peripheralName = "BoxedUpGlove"

    // MARK: - Packet Format
    /// Bytes per sample: timestamp(4) + accXYZ(12) + rotXYZ(12) = 28
    static let bytesPerSample = 28
    /// Samples per BLE notification batch
    static let batchSize = 5
    /// Expected notification payload size
    static let expectedPayloadSize = bytesPerSample * batchSize  // 140 bytes

    // MARK: - Control Commands
    static let startCaptureCommand: Data = Data([0x01])
    static let stopCaptureCommand: Data  = Data([0x00])
}
