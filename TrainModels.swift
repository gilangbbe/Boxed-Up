#!/usr/bin/env swift
//
//  TrainModels.swift
//  Boxed Up — ML Model Trainer
//
//  Trains two Core ML models from collected training data:
//    1. PunchClassifier  — 3-class (jab, hook, uppercut), prediction window 50
//    2. PunchDetector    — 2-class (punch, other), prediction window 25
//
//  Usage:
//    swift TrainModels.swift BoxedUp_TrainingData.csv
//
//  Output:
//    ./MLModels/PunchClassifier.mlmodel
//    ./MLModels/PunchDetector.mlmodel

import Foundation
import CreateML
import TabularData

// MARK: - Arguments

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift TrainModels.swift <path-to-BoxedUp_TrainingData.csv>")
    exit(1)
}

let csvPath = CommandLine.arguments[1]
let csvURL = URL(fileURLWithPath: csvPath)
let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("MLModels")
let classifierTrainingDir = outputDir.appendingPathComponent("ClassifierTraining")
let detectorTrainingDir = outputDir.appendingPathComponent("DetectorTraining")

// MARK: - Parse Consolidated CSV

print("📂 Loading training data from: \(csvPath)")

let csvContent = try String(contentsOf: csvURL, encoding: .utf8)
let lines = csvContent.components(separatedBy: "\n").dropFirst() // skip header

struct SessionData {
    let sessionId: String
    let label: String
    var rows: [String] = [] // CSV rows without sessionId and label columns
}

var sessions: [String: SessionData] = [:]

for line in lines {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { continue }

    let cols = trimmed.components(separatedBy: ",")
    guard cols.count == 9 else { continue }

    let sessionId = cols[0]
    let label = cols[1]
    let dataRow = cols[2...].joined(separator: ",") // timestamp,accX,...,rotZ

    if sessions[sessionId] == nil {
        sessions[sessionId] = SessionData(sessionId: sessionId, label: label)
    }
    sessions[sessionId]?.rows.append(dataRow)
}

print("✅ Found \(sessions.count) sessions")

// Count per label
var labelCounts: [String: Int] = [:]
for session in sessions.values {
    labelCounts[session.label, default: 0] += 1
}
for (label, count) in labelCounts.sorted(by: { $0.key < $1.key }) {
    print("   \(label): \(count) sessions")
}

// MARK: - Write Per-Label Directories

func writePerLabelDirectories(sessions: [String: SessionData], baseDir: URL, labelMapping: ((String) -> String)? = nil) throws {
    // Clean previous
    try? FileManager.default.removeItem(at: baseDir)

    for (_, session) in sessions {
        let label = labelMapping?(session.label) ?? session.label
        let dir = baseDir.appendingPathComponent(label)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileURL = dir.appendingPathComponent("\(session.sessionId).csv")
        let header = "timestamp,accX,accY,accZ,rotX,rotY,rotZ\n"
        let content = header + session.rows.joined(separator: "\n") + "\n"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Train Model 1: Punch Type Classifier (jab/hook/uppercut only)

print("\n🥊 Training Model 1: PunchClassifier (jab / hook / uppercut)")
print("   Prediction window: 50 samples (1.0s at 50 Hz)")

let punchOnlySessions = sessions.filter { $0.value.label != "other" }
print("   Using \(punchOnlySessions.count) sessions (excluding 'other')")

try writePerLabelDirectories(sessions: punchOnlySessions, baseDir: classifierTrainingDir)

let classifierParams = MLActivityClassifier.ModelParameters(
    validation: .split(strategy: .automatic),
    batchSize: nil,
    maximumIterations: 20,
    predictionWindowSize: 50
)

let classifier = try MLActivityClassifier(
    trainingData: .labeledDirectories(at: classifierTrainingDir),
    featureColumns: ["accX", "accY", "accZ", "rotX", "rotY", "rotZ"],
    labelColumn: "label",
    recordingFileColumn: "filename",
    parameters: classifierParams
)

print("   Training metrics:  \(classifier.trainingMetrics.classificationError)")
print("   Validation metrics: \(classifier.validationMetrics.classificationError)")

let classifierOutput = outputDir.appendingPathComponent("PunchClassifier.mlmodel")
try classifier.write(to: classifierOutput, metadata: MLModelMetadata(
    author: "Boxed Up",
    shortDescription: "Classifies wrist-mounted punch type: jab, hook, or uppercut",
    version: "1.0"
))
print("   ✅ Saved to: \(classifierOutput.path)")

// MARK: - Train Model 2: Punch Detector (punch vs other)

print("\n🔍 Training Model 2: PunchDetector (punch / other)")
print("   Prediction window: 25 samples (0.5s at 50 Hz)")

// Map jab/hook/uppercut → "punch", keep "other" as-is
try writePerLabelDirectories(sessions: sessions, baseDir: detectorTrainingDir) { label in
    label == "other" ? "other" : "punch"
}

let detectorParams = MLActivityClassifier.ModelParameters(
    validation: .split(strategy: .automatic),
    batchSize: nil,
    maximumIterations: 20,
    predictionWindowSize: 25
)

let detector = try MLActivityClassifier(
    trainingData: .labeledDirectories(at: detectorTrainingDir),
    featureColumns: ["accX", "accY", "accZ", "rotX", "rotY", "rotZ"],
    labelColumn: "label",
    recordingFileColumn: "filename",
    parameters: detectorParams
)

print("   Training metrics:  \(detector.trainingMetrics.classificationError)")
print("   Validation metrics: \(detector.validationMetrics.classificationError)")

let detectorOutput = outputDir.appendingPathComponent("PunchDetector.mlmodel")
try detector.write(to: detectorOutput, metadata: MLModelMetadata(
    author: "Boxed Up",
    shortDescription: "Detects whether wrist motion is a punch or non-punch activity",
    version: "1.0"
))
print("   ✅ Saved to: \(detectorOutput.path)")

// MARK: - Cleanup temp directories

try? FileManager.default.removeItem(at: classifierTrainingDir)
try? FileManager.default.removeItem(at: detectorTrainingDir)

print("\n🎉 Done! Models saved to ./MLModels/")
print("   → PunchClassifier.mlmodel (3-class: jab/hook/uppercut)")
print("   → PunchDetector.mlmodel   (2-class: punch/other)")
print("\nNext: Drag both .mlmodel files into your Xcode project's iOS target.")
