//
//  DataCollectionViewModel.swift
//  Boxed Up
//
//  Created on 14/04/26.
//

import Foundation

/// Manages training data collection: recording sessions, saving CSV files, and exporting.
@Observable
class DataCollectionViewModel {

    let sessionManager: PhoneSessionManager

    // MARK: - State

    var selectedLabel: DataCollectionLabel = .jab
    private(set) var isRecording = false
    private(set) var countdown: Int? = nil
    private(set) var recordingBuffer: [MotionSample] = []
    private(set) var sessionCounts: [DataCollectionLabel: Int] = [:]
    private(set) var statusMessage: String = "Select a punch type and tap Record"

    static let recordingDuration: TimeInterval = 3.0

    // MARK: - Init

    init(sessionManager: PhoneSessionManager) {
        self.sessionManager = sessionManager
        loadSessionCounts()
        setupMotionCallback()
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording, countdown == nil else { return }

        recordingBuffer = []
        countdown = 3
        statusMessage = "Get ready..."

        Task { @MainActor in
            for i in stride(from: 3, through: 1, by: -1) {
                countdown = i
                try? await Task.sleep(for: .seconds(1.0))
            }
            countdown = nil
            beginCapture()
        }
    }

    private func beginCapture() {
        isRecording = true
        recordingBuffer = []
        statusMessage = "Recording \(selectedLabel.displayName)..."

        sessionManager.send(.startCapture)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.recordingDuration))
            stopRecording()
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        sessionManager.send(.stopCapture)

        let samples = recordingBuffer
        recordingBuffer = []

        if samples.isEmpty {
            statusMessage = "No data received. Check Watch connection."
            return
        }

        saveSession(label: selectedLabel, samples: samples)

        let count = sessionCounts[selectedLabel, default: 0]
        statusMessage = "Saved! \(selectedLabel.displayName): \(count) sessions"
    }

    // MARK: - Persistence

    private func saveSession(label: DataCollectionLabel, samples: [MotionSample]) {
        let directory = trainingDataDirectory(for: label)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let count = sessionCounts[label, default: 0] + 1
        let filename = "session_\(timestamp)_\(String(format: "%03d", count)).csv"
        let fileURL = directory.appendingPathComponent(filename)

        var csv = "timestamp,accX,accY,accZ,rotX,rotY,rotZ\n"
        for sample in samples {
            csv += String(format: "%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                          sample.timestamp, sample.accX, sample.accY, sample.accZ,
                          sample.rotX, sample.rotY, sample.rotZ)
        }

        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
        sessionCounts[label] = count
    }

    private func trainingDataDirectory(for label: DataCollectionLabel) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("TrainingData/\(label.rawValue)")
    }

    private var trainingDataRoot: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("TrainingData")
    }

    private func loadSessionCounts() {
        for label in DataCollectionLabel.allCases {
            let directory = trainingDataDirectory(for: label)
            let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            sessionCounts[label] = files.filter { $0.pathExtension == "csv" }.count
        }
    }

    var totalSessions: Int {
        sessionCounts.values.reduce(0, +)
    }

    // MARK: - Export

    /// Creates a consolidated CSV with all sessions for Create ML training.
    /// Format: sessionId, label, timestamp, accX, accY, accZ, rotX, rotY, rotZ
    func exportTrainingData() -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documents.appendingPathComponent("BoxedUp_TrainingData.csv")

        var csv = "sessionId,label,timestamp,accX,accY,accZ,rotX,rotY,rotZ\n"

        for label in DataCollectionLabel.allCases {
            let directory = trainingDataDirectory(for: label)
            guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { continue }

            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "csv" {
                let sessionId = file.deletingPathExtension().lastPathComponent
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }

                let lines = content.components(separatedBy: "\n").dropFirst() // skip header
                for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    csv += "\(sessionId),\(label.rawValue),\(line)\n"
                }
            }
        }

        try? csv.write(to: exportURL, atomically: true, encoding: .utf8)
        return exportURL
    }

    func deleteAllData() {
        try? FileManager.default.removeItem(at: trainingDataRoot)
        for label in DataCollectionLabel.allCases {
            sessionCounts[label] = 0
        }
        statusMessage = "All training data deleted"
    }

    // MARK: - Motion Callback

    func setupMotionCallback() {
        sessionManager.onMotionData = { [weak self] samples in
            guard let self else { return }
            Task { @MainActor in
                if self.isRecording {
                    self.recordingBuffer.append(contentsOf: samples)
                }
            }
        }
    }
}
