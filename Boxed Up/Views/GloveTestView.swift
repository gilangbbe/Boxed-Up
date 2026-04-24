//
//  GloveTestView.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import SwiftUI

/// Test view for verifying ESP32 Smart Glove BLE connection and MPU6050 motion data.
/// Shows real-time 6-axis IMU values, sample rate, and acceleration magnitude.
struct GloveTestView: View {
    @Bindable var gloveManager: GloveSessionManager
    var onDone: () -> Void

    // MARK: - Live Data State
    @State private var latestSample: MotionSample?
    @State private var sampleCount: Int = 0
    @State private var samplesPerSecond: Double = 0
    @State private var isCapturing: Bool = false
    @State private var recentSamples: [MotionSample] = []

    // For sample rate calculation
    @State private var rateTimer: Timer?
    @State private var samplesThisSecond: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    connectionSection
                    if gloveManager.isGloveConnected {
                        captureControlSection
                        liveDataSection
                        statsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Glove Sensor Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        gloveManager.stopCapture()
                        gloveManager.stopScanning()
                        rateTimer?.invalidate()
                        onDone()
                    }
                }
            }
            .onAppear { setupCallbacks() }
            .onDisappear {
                gloveManager.stopCapture()
                gloveManager.stopScanning()
                rateTimer?.invalidate()
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: gloveManager.isGloveConnected
                      ? "hand.raised.fingers.spread.fill" : "hand.raised.slash.fill")
                    .font(.title2)
                    .foregroundStyle(gloveManager.isGloveConnected ? .green : .red)

                VStack(alignment: .leading) {
                    Text(gloveManager.isGloveConnected
                         ? "Glove Connected" : "Glove Not Connected")
                        .font(.headline)
                        .foregroundStyle(gloveManager.isGloveConnected ? .green : .red)

                    if let name = gloveManager.peripheralName {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if !gloveManager.isGloveConnected {
                Button {
                    if gloveManager.isScanning {
                        gloveManager.stopScanning()
                    } else {
                        gloveManager.startScanning()
                    }
                } label: {
                    HStack {
                        if gloveManager.isScanning {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(gloveManager.isScanning ? "Scanning..." : "Scan for Glove")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(gloveManager.isScanning ? .orange : .blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Capture Control

    private var captureControlSection: some View {
        Button {
            if isCapturing {
                gloveManager.stopCapture()
                isCapturing = false
                rateTimer?.invalidate()
                rateTimer = nil
            } else {
                sampleCount = 0
                samplesPerSecond = 0
                samplesThisSecond = 0
                recentSamples = []
                latestSample = nil
                gloveManager.startCapture()
                isCapturing = true
                startRateTimer()
            }
        } label: {
            HStack {
                Image(systemName: isCapturing ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(isCapturing ? "Stop Capture" : "Start Capture")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isCapturing ? .red : .green)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Live Data Display

    private var liveDataSection: some View {
        VStack(spacing: 12) {
            Text("Live IMU Data")
                .font(.headline)

            if let sample = latestSample {
                VStack(spacing: 8) {
                    Text("Accelerometer (g)")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 16) {
                        axisView(label: "X", value: sample.accX, color: .red)
                        axisView(label: "Y", value: sample.accY, color: .green)
                        axisView(label: "Z", value: sample.accZ, color: .blue)
                    }

                    Text("Gyroscope (°/s)")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    HStack(spacing: 16) {
                        axisView(label: "X", value: sample.rotX, color: .red)
                        axisView(label: "Y", value: sample.rotY, color: .green)
                        axisView(label: "Z", value: sample.rotZ, color: .blue)
                    }

                    Divider()

                    HStack {
                        Text("Accel Magnitude")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.3f g", sample.accelerationMagnitude))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(sample.accelerationMagnitude > 1.5 ? .red : .primary)
                    }
                }
            } else if isCapturing {
                Text("Waiting for data...")
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap Start Capture to begin")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 12) {
            Text("Stream Stats")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: "Samples", value: "\(sampleCount)", icon: "number")
                statCard(title: "Sample Rate", value: String(format: "%.0f Hz", samplesPerSecond), icon: "waveform")
                statCard(title: "Batches", value: "\(sampleCount / max(GloveConstants.batchSize, 1))", icon: "shippingbox")
                statCard(title: "Status", value: isCapturing ? "Streaming" : "Idle",
                         icon: isCapturing ? "antenna.radiowaves.left.and.right" : "pause.circle")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helper Views

    private func axisView(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(String(format: "%+.3f", value))
                .font(.system(.body, design: .monospaced))
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Setup

    private func setupCallbacks() {
        gloveManager.onMotionData = { samples in
            Task { @MainActor in
                latestSample = samples.last
                sampleCount += samples.count
                samplesThisSecond += samples.count
                recentSamples.append(contentsOf: samples)
                if recentSamples.count > 200 {
                    recentSamples.removeFirst(recentSamples.count - 200)
                }
            }
        }
    }

    private func startRateTimer() {
        rateTimer?.invalidate()
        samplesThisSecond = 0
        rateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                samplesPerSecond = Double(samplesThisSecond)
                samplesThisSecond = 0
            }
        }
    }
}
