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
    let gloveManager: GloveSessionManager

    // MARK: - State

    var selectedLabel: DataCollectionLabel = .jab
    var selectedSource: DataCollectionSource = .rightGlove
    private(set) var isRecording = false
    private(set) var countdown: Int? = nil
    private(set) var watchRecordingBuffer: [MotionSample] = []
    private(set) var gloveRecordingBuffer: [MotionSample] = []
    private(set) var sessionCountsBySource: [DataCollectionSource: [DataCollectionLabel: Int]] = [:]
    private(set) var statusMessage: String = "Select a punch type and tap Record"

    static let recordingDuration: TimeInterval = 3.0

    // MARK: - Init

    init(sessionManager: PhoneSessionManager, gloveManager: GloveSessionManager) {
        self.sessionManager = sessionManager
        self.gloveManager = gloveManager
        loadSessionCounts()
        setupMotionCallback()
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording, countdown == nil else { return }
        guard canRecord else {
            statusMessage = unavailableStatus
            return
        }

        watchRecordingBuffer = []
        gloveRecordingBuffer = []
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
        watchRecordingBuffer = []
        gloveRecordingBuffer = []
        statusMessage = "Recording \(selectedLabel.displayName)..."

        if selectedSource.includesWatch {
            sessionManager.send(.startCapture)
        }
        if selectedSource.includesGlove {
            gloveManager.startCapture()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.recordingDuration))
            stopRecording()
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        if selectedSource.includesWatch {
            sessionManager.send(.stopCapture)
        }
        if selectedSource.includesGlove {
            gloveManager.stopCapture()
        }

        let watchSamples = watchRecordingBuffer
        let gloveSamples = gloveRecordingBuffer
        watchRecordingBuffer = []
        gloveRecordingBuffer = []

        let timestampStem = Self.timestampString(from: Date())
        var savedParts: [String] = []

        if selectedSource.includesWatch {
            if watchSamples.isEmpty {
                savedParts.append("Left(Watch): no data")
            } else {
                let count = saveSession(label: selectedLabel, samples: watchSamples, source: .leftWatch, sessionStem: timestampStem)
                savedParts.append("Left(Watch): \(count)")
            }
        }

        if selectedSource.includesGlove {
            if gloveSamples.isEmpty {
                savedParts.append("Right(Glove): no data")
            } else {
                let count = saveSession(label: selectedLabel, samples: gloveSamples, source: .rightGlove, sessionStem: timestampStem)
                savedParts.append("Right(Glove): \(count)")
            }
        }

        if savedParts.allSatisfy({ $0.contains("no data") }) {
            statusMessage = "No data received. Check source connection(s)."
        } else {
            statusMessage = "Saved \(selectedLabel.displayName) • " + savedParts.joined(separator: " | ")
        }
    }

    // MARK: - Persistence

    private func saveSession(
        label: DataCollectionLabel,
        samples: [MotionSample],
        source: DataCollectionSource,
        sessionStem: String
    ) -> Int {
        let directory = trainingDataDirectory(for: label, source: source)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let currentCount = sessionCountsBySource[source]?[label, default: 0] ?? 0
        let count = currentCount + 1
        let filename = "session_\(sessionStem)_\(String(format: "%03d", count)).csv"
        let fileURL = directory.appendingPathComponent(filename)

        var csv = "timestamp,accX,accY,accZ,rotX,rotY,rotZ\n"
        for sample in samples {
            csv += String(format: "%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                          sample.timestamp, sample.accX, sample.accY, sample.accZ,
                          sample.rotX, sample.rotY, sample.rotZ)
        }

        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
        var sourceCounts = sessionCountsBySource[source] ?? [:]
        sourceCounts[label] = count
        sessionCountsBySource[source] = sourceCounts
        return count
    }

    private func trainingDataDirectory(for label: DataCollectionLabel, source: DataCollectionSource) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("TrainingData/\(source.directoryName)/\(label.rawValue)")
    }

    private var trainingDataRoot: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("TrainingData")
    }

    private func loadSessionCounts() {
        for source in DataCollectionSource.physicalSources {
            var sourceCounts: [DataCollectionLabel: Int] = [:]
            for label in DataCollectionLabel.allCases {
                let directory = trainingDataDirectory(for: label, source: source)
                let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
                sourceCounts[label] = files.filter { $0.pathExtension == "csv" }.count
            }
            sessionCountsBySource[source] = sourceCounts
        }
    }

    var totalSessions: Int {
        DataCollectionSource.physicalSources.reduce(0) { partial, source in
            partial + (sessionCountsBySource[source]?.values.reduce(0, +) ?? 0)
        }
    }

    var canRecord: Bool {
        switch selectedSource {
        case .leftWatch:
            return sessionManager.isWatchReachable
        case .rightGlove:
            return gloveManager.isGloveConnected
        case .both:
            return sessionManager.isWatchReachable && gloveManager.isGloveConnected
        }
    }

    var recordingSampleCount: Int {
        switch selectedSource {
        case .leftWatch:
            return watchRecordingBuffer.count
        case .rightGlove:
            return gloveRecordingBuffer.count
        case .both:
            return watchRecordingBuffer.count + gloveRecordingBuffer.count
        }
    }

    var unavailableStatus: String {
        switch selectedSource {
        case .leftWatch:
            return "Left (Watch) not connected"
        case .rightGlove:
            return "Right (Smart Glove) not connected"
        case .both:
            return "Both Watch and Smart Glove must be connected"
        }
    }

    func sessionCount(for label: DataCollectionLabel, source: DataCollectionSource) -> Int {
        sessionCountsBySource[source]?[label, default: 0] ?? 0
    }

    func sessionCountText(for label: DataCollectionLabel) -> String {
        switch selectedSource {
        case .leftWatch:
            return "\(sessionCount(for: label, source: .leftWatch))"
        case .rightGlove:
            return "\(sessionCount(for: label, source: .rightGlove))"
        case .both:
            let left = sessionCount(for: label, source: .leftWatch)
            let right = sessionCount(for: label, source: .rightGlove)
            return "L\(left) / R\(right)"
        }
    }

    func progressCount(for label: DataCollectionLabel) -> Int {
        switch selectedSource {
        case .leftWatch:
            return sessionCount(for: label, source: .leftWatch)
        case .rightGlove:
            return sessionCount(for: label, source: .rightGlove)
        case .both:
            // Use the smaller side as progress when collecting both-hand datasets.
            return min(
                sessionCount(for: label, source: .leftWatch),
                sessionCount(for: label, source: .rightGlove)
            )
        }
    }

    // MARK: - Export

    /// Creates a consolidated CSV for separate-hand model training.
    /// Format: sessionId,label,handSource,timestamp,accX,accY,accZ,rotX,rotY,rotZ
    func exportTrainingData() -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documents.appendingPathComponent("BoxedUp_TrainingData_SeparateHands.csv")

        var csv = "sessionId,label,handSource,timestamp,accX,accY,accZ,rotX,rotY,rotZ\n"

        for source in DataCollectionSource.physicalSources {
            for label in DataCollectionLabel.allCases {
                let directory = trainingDataDirectory(for: label, source: source)
                guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { continue }

                for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "csv" {
                    let sessionId = file.deletingPathExtension().lastPathComponent
                    guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }

                    let lines = content.components(separatedBy: "\n").dropFirst()
                    for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                        csv += "\(sessionId),\(label.rawValue),\(source.rawValue),\(line)\n"
                    }
                }
            }
        }

        try? csv.write(to: exportURL, atomically: true, encoding: .utf8)
        return exportURL
    }

    func deleteAllData() {
        try? FileManager.default.removeItem(at: trainingDataRoot)
        for source in DataCollectionSource.physicalSources {
            var sourceCounts: [DataCollectionLabel: Int] = [:]
            for label in DataCollectionLabel.allCases {
                sourceCounts[label] = 0
            }
            sessionCountsBySource[source] = sourceCounts
        }
        statusMessage = "All training data deleted"
    }

    // MARK: - Motion Callback

    func setupMotionCallback() {
        sessionManager.onMotionData = { [weak self] samples in
            guard let self else { return }
            Task { @MainActor in
                if self.isRecording && self.selectedSource.includesWatch {
                    self.watchRecordingBuffer.append(contentsOf: samples)
                }
            }
        }

        gloveManager.onMotionData = { [weak self] samples in
            guard let self else { return }
            Task { @MainActor in
                if self.isRecording && self.selectedSource.includesGlove {
                    self.gloveRecordingBuffer.append(contentsOf: samples)
                }
            }
        }
    }

    func teardownMotionCallbacks() {
        sessionManager.onMotionData = nil
        gloveManager.onMotionData = nil
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}
