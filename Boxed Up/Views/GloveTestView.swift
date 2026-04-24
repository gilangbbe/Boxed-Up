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
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        connectionSection
                        if gloveManager.isGloveConnected {
                            captureControlSection
                            liveDataSection
                            statsSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Glove Sensor Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.05, green: 0.05, blue: 0.07), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        gloveManager.stopCapture()
                        gloveManager.stopScanning()
                        rateTimer?.invalidate()
                        onDone()
                    }
                    .foregroundStyle(.red)
                }
            }
            .onAppear { setupCallbacks() }
            .onDisappear {
                gloveManager.stopCapture()
                gloveManager.stopScanning()
                rateTimer?.invalidate()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((gloveManager.isGloveConnected ? Color.green : Color.red).opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: gloveManager.isGloveConnected
                          ? "hand.raised.fingers.spread.fill" : "hand.raised.slash.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(gloveManager.isGloveConnected ? .green : .red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(gloveManager.isGloveConnected ? "Glove Connected" : "Glove Not Connected")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(gloveManager.isGloveConnected ? .green : .red)
                    if let name = gloveManager.peripheralName {
                        Text(name)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.45))
                    }
                }
                Spacer()
                Circle()
                    .fill(gloveManager.isGloveConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }

            if !gloveManager.isGloveConnected {
                Button {
                    if gloveManager.isScanning { gloveManager.stopScanning() }
                    else { gloveManager.startScanning() }
                } label: {
                    HStack(spacing: 8) {
                        if gloveManager.isScanning {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 14))
                        }
                        Text(gloveManager.isScanning ? "Scanning for Glove..." : "Scan for Glove")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(
                        gloveManager.isScanning
                            ? Color(red: 1, green: 0.55, blue: 0.1)
                            : Color(red: 0.2, green: 0.5, blue: 1.0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.14), lineWidth: 1))
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
                sampleCount = 0; samplesPerSecond = 0; samplesThisSecond = 0
                recentSamples = []; latestSample = nil
                gloveManager.startCapture()
                isCapturing = true
                startRateTimer()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isCapturing ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 18))
                Text(isCapturing ? "STOP CAPTURE" : "START CAPTURE")
                    .font(.system(size: 15, weight: .bold)).tracking(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                LinearGradient(
                    colors: isCapturing
                        ? [Color.red.opacity(0.9), Color.red.opacity(0.75)]
                        : [Color(red: 0.15, green: 0.75, blue: 0.35),
                           Color(red: 0.05, green: 0.60, blue: 0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: (isCapturing ? Color.red : Color.green).opacity(0.35), radius: 8, y: 3)
        }
    }

    // MARK: - Live Data Display

    private var liveDataSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("LIVE IMU DATA")
                    .font(.system(size: 10, weight: .bold)).tracking(2)
                    .foregroundStyle(Color(white: 0.38))
                Spacer()
                if isCapturing {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("LIVE").font(.system(size: 10, weight: .bold)).tracking(1)
                            .foregroundStyle(.green)
                    }
                }
            }

            if let sample = latestSample {
                VStack(spacing: 10) {
                    Text("ACCELEROMETER (g)")
                        .font(.system(size: 9, weight: .bold)).tracking(1.5)
                        .foregroundStyle(Color(white: 0.38))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        axisView(label: "X", value: sample.accX, color: .red)
                        axisView(label: "Y", value: sample.accY, color: .green)
                        axisView(label: "Z", value: sample.accZ, color: .blue)
                    }

                    Text("GYROSCOPE (°/s)")
                        .font(.system(size: 9, weight: .bold)).tracking(1.5)
                        .foregroundStyle(Color(white: 0.38))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    HStack(spacing: 8) {
                        axisView(label: "X", value: sample.rotX, color: .red)
                        axisView(label: "Y", value: sample.rotY, color: .green)
                        axisView(label: "Z", value: sample.rotZ, color: .blue)
                    }

                    Rectangle().fill(Color(white: 0.14)).frame(height: 1).padding(.vertical, 2)

                    HStack {
                        Text("Accel Magnitude")
                            .font(.system(size: 13)).foregroundStyle(Color(white: 0.55))
                        Spacer()
                        Text(String(format: "%.3f g", sample.accelerationMagnitude))
                            .font(.system(size: 18, weight: .bold).monospacedDigit())
                            .foregroundStyle(sample.accelerationMagnitude > 1.5 ? .red : .white)
                    }
                }
            } else {
                Text(isCapturing ? "Waiting for data..." : "Tap Start Capture to begin")
                    .font(.system(size: 13)).foregroundStyle(Color(white: 0.38))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.14), lineWidth: 1))
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 12) {
            Text("STREAM STATS")
                .font(.system(size: 10, weight: .bold)).tracking(2)
                .foregroundStyle(Color(white: 0.38))
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard(title: "Samples", value: "\(sampleCount)", icon: "number")
                statCard(title: "Sample Rate", value: String(format: "%.0f Hz", samplesPerSecond), icon: "waveform")
                statCard(title: "Batches", value: "\(sampleCount / max(GloveConstants.batchSize, 1))", icon: "shippingbox")
                statCard(title: "Status", value: isCapturing ? "Streaming" : "Idle",
                         icon: isCapturing ? "antenna.radiowaves.left.and.right" : "pause.circle")
            }
        }
        .padding(16)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.14), lineWidth: 1))
    }

    // MARK: - Helper Views

    private func axisView(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold)).foregroundStyle(color)
            Text(String(format: "%+.3f", value))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.22), lineWidth: 1))
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16)).foregroundStyle(Color(white: 0.40))
            Text(value)
                .font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(.white)
            Text(title)
                .font(.system(size: 10)).foregroundStyle(Color(white: 0.38))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.13), lineWidth: 1))
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
