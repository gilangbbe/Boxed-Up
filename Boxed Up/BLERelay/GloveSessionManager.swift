//
//  GloveSessionManager.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation
import CoreBluetooth

/// Manages BLE communication with the ESP32 Smart Glove.
/// Scans for the glove, connects, and streams motion data via notifications.
@Observable
class GloveSessionManager: NSObject {

    // MARK: - Published State

    private(set) var isGloveConnected: Bool = false
    private(set) var isScanning: Bool = false
    private(set) var peripheralName: String?

    /// Called when motion samples arrive from glove.
    var onMotionData: (([MotionSample]) -> Void)?

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var glovePeripheral: CBPeripheral?
    private var motionCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?
    private var shouldReconnect = false

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public API

    /// Start scanning for the BoxedUpGlove BLE peripheral.
    /// If the glove is already connected, this is a no-op.
    func startScanning() {
        guard !isGloveConnected else { return }   // already connected — nothing to do
        guard centralManager.state == .poweredOn else {
            print("[Glove] BLE not powered on — state: \(centralManager.state.rawValue)")
            return
        }
        guard !isScanning else { return }
        isScanning = true
        shouldReconnect = true
        centralManager.scanForPeripherals(
            withServices: [GloveConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        print("[Glove] Scanning for BoxedUpGlove...")
    }

    /// Stop scanning and disconnect the peripheral entirely.
    func stopScanning() {
        shouldReconnect = false
        centralManager.stopScan()
        isScanning = false
        if let peripheral = glovePeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    /// Stop BLE scanning while keeping an existing connection alive.
    /// Use this when changing game-mode selection so the glove badge stays green.
    func stopScanningKeepConnection() {
        shouldReconnect = false
        centralManager.stopScan()
        isScanning = false
        print("[Glove] Scan stopped (connection kept)")
    }

    /// Send start capture command to the glove.
    func startCapture() {
        guard let characteristic = controlCharacteristic else {
            print("[Glove] Control characteristic not available")
            return
        }
        glovePeripheral?.writeValue(GloveConstants.startCaptureCommand, for: characteristic, type: .withResponse)
        print("[Glove] Sent start capture")
    }

    /// Send stop capture command to the glove.
    func stopCapture() {
        guard let characteristic = controlCharacteristic else { return }
        glovePeripheral?.writeValue(GloveConstants.stopCaptureCommand, for: characteristic, type: .withResponse)
        print("[Glove] Sent stop capture")
    }

    // MARK: - Packet Parsing

    /// Parses a BLE notification payload into an array of MotionSamples.
    func parseMotionBatch(data: Data) -> [MotionSample] {
        let sampleSize = GloveConstants.bytesPerSample
        var samples: [MotionSample] = []

        for i in stride(from: 0, to: data.count, by: sampleSize) {
            guard i + sampleSize <= data.count else { break }

            let slice = data[i..<(i + sampleSize)]

            let ts    = slice.loadLittleEndian(fromByteOffset: 0, as: UInt32.self)
            let accX  = slice.loadLittleEndian(fromByteOffset: 4, as: Float32.self)
            let accY  = slice.loadLittleEndian(fromByteOffset: 8, as: Float32.self)
            let accZ  = slice.loadLittleEndian(fromByteOffset: 12, as: Float32.self)
            let rotX  = slice.loadLittleEndian(fromByteOffset: 16, as: Float32.self)
            let rotY  = slice.loadLittleEndian(fromByteOffset: 20, as: Float32.self)
            let rotZ  = slice.loadLittleEndian(fromByteOffset: 24, as: Float32.self)

            samples.append(MotionSample(
                timestamp: TimeInterval(ts) / 1000.0,
                accX: Double(accX), accY: Double(accY), accZ: Double(accZ),
                rotX: Double(rotX), rotY: Double(rotY), rotZ: Double(rotZ)
            ))
        }
        return samples
    }
}

// MARK: - CBCentralManagerDelegate

extension GloveSessionManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[Glove] BLE state: \(central.state.rawValue)")
        if central.state == .poweredOn && shouldReconnect {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("[Glove] Discovered: \(peripheral.name ?? "unknown") RSSI: \(RSSI)")
        centralManager.stopScan()
        isScanning = false

        glovePeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[Glove] Connected to \(peripheral.name ?? "unknown")")
        Task { @MainActor in
            self.isGloveConnected = true
            self.peripheralName = peripheral.name
        }
        peripheral.discoverServices([GloveConstants.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[Glove] Disconnected: \(error?.localizedDescription ?? "clean")")
        Task { @MainActor in
            self.isGloveConnected = false
            self.motionCharacteristic = nil
            self.controlCharacteristic = nil
        }

        // Auto-reconnect if we still want to be connected
        if shouldReconnect {
            print("[Glove] Attempting reconnect...")
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[Glove] Failed to connect: \(error?.localizedDescription ?? "unknown")")
        Task { @MainActor in
            self.isGloveConnected = false
        }
        // Retry scan
        if shouldReconnect {
            startScanning()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension GloveSessionManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == GloveConstants.serviceUUID {
            peripheral.discoverCharacteristics(
                [GloveConstants.motionCharUUID, GloveConstants.controlCharUUID],
                for: service
            )
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case GloveConstants.motionCharUUID:
                motionCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("[Glove] Subscribed to motion notifications")
            case GloveConstants.controlCharUUID:
                controlCharacteristic = characteristic
                print("[Glove] Found control characteristic")
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == GloveConstants.motionCharUUID,
              let data = characteristic.value else { return }

        let samples = parseMotionBatch(data: data)
        if !samples.isEmpty {
            onMotionData?(samples)
        }
    }
}

// MARK: - Data Extension for Little-Endian Parsing

private extension Data {
    func loadLittleEndian<T: FixedWidthInteger>(fromByteOffset offset: Int, as type: T.Type) -> T {
        let range = startIndex + offset ..< startIndex + offset + MemoryLayout<T>.size
        return subdata(in: range).withUnsafeBytes { $0.loadUnaligned(as: T.self) }
    }

    func loadLittleEndian(fromByteOffset offset: Int, as type: Float32.Type) -> Float32 {
        let bits = loadLittleEndian(fromByteOffset: offset, as: UInt32.self)
        return Float32(bitPattern: bits)
    }
}
