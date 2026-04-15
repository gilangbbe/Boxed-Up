//
//  PunchClassifierService.swift
//  Boxed Up
//
//  Created on 14/04/26.
//

import CoreML
import Foundation

/// Wraps the CNN-based PunchClassifier and PunchDetector Core ML models for real-time inference.
/// Two-stage pipeline: Detector checks if motion is a punch → Classifier identifies punch type.
///
/// CNN 1D models are stateless (no LSTM recurrent state), which eliminates state carryover issues
/// between actions and generalizes better than the CreateML Activity Classifier approach.
class PunchClassifierService {

    private let classifierModel: MLModel
    private let detectorModel: MLModel

    static let classifierWindowSize = 50  // 1.0s at 50 Hz
    static let detectorWindowSize = 25    // 0.5s at 50 Hz
    private static let channelCount = 6   // accX, accY, accZ, rotX, rotY, rotZ

    init?() {
        guard let classifierURL = Bundle.main.url(forResource: "PunchClassifier_CNN", withExtension: "mlmodelc"),
              let detectorURL = Bundle.main.url(forResource: "PunchDetector_CNN", withExtension: "mlmodelc") else {
            print("[PunchClassifierService] CNN model files not found in bundle")
            return nil
        }

        do {
            classifierModel = try MLModel(contentsOf: classifierURL)
            detectorModel = try MLModel(contentsOf: detectorURL)
        } catch {
            print("[PunchClassifierService] Failed to load models: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Detection (Stage 1)

    /// Returns true if the motion window looks like a punch.
    func detectPunch(from samples: [MotionSample]) -> (isPunch: Bool, confidence: Double) {
        let windowSize = Self.detectorWindowSize
        guard samples.count >= windowSize else { return (false, 0) }

        let window = Array(samples.suffix(windowSize))

        do {
            let input = try buildCNNInput(samples: window, windowSize: windowSize)
            let output = try detectorModel.prediction(from: input)

            let label = output.featureValue(for: "classLabel")?.stringValue ?? "other"
            // Probability dict output name from model: "var_83"
            let probs = output.featureValue(for: "var_83")?.dictionaryValue as? [String: Double] ?? [:]
            let punchConfidence = probs["punch"] ?? 0

            return (label == "punch", punchConfidence)
        } catch {
            print("[PunchClassifierService] Detection error: \(error.localizedDescription)")
            return (false, 0)
        }
    }

    // MARK: - Classification (Stage 2)

    /// Classifies the punch type from a motion window.
    func classifyPunch(from samples: [MotionSample]) -> (punchType: PunchType, confidence: Double) {
        let windowSize = Self.classifierWindowSize
        guard samples.count >= windowSize else {
            return (.jab, 0)
        }

        let window = Array(samples.suffix(windowSize))

        do {
            let input = try buildCNNInput(samples: window, windowSize: windowSize)
            let output = try classifierModel.prediction(from: input)

            let label = output.featureValue(for: "classLabel")?.stringValue ?? "jab"
            // Probability dict output name from model: "var_84"
            let probs = output.featureValue(for: "var_84")?.dictionaryValue as? [String: Double] ?? [:]
            let confidence = probs[label] ?? 0

            let punchType = PunchType(rawValue: label) ?? .jab
            return (punchType, confidence)
        } catch {
            print("[PunchClassifierService] Classification error: \(error.localizedDescription)")
            return (.jab, 0)
        }
    }

    /// No-op for CNN models (stateless). Kept for API compatibility.
    func resetState() {
        // CNN models have no recurrent state — nothing to reset.
    }

    /// No-op for CNN models (stateless). Kept for API compatibility.
    func resetDetectorState() {
        // CNN models have no recurrent state — nothing to reset.
    }

    // MARK: - Feature Provider

    /// Builds a single `motionData` MLMultiArray shaped [1, 6, windowSize] for CNN input.
    /// Channel order: [accX, accY, accZ, rotX, rotY, rotZ]
    private func buildCNNInput(samples: [MotionSample], windowSize: Int) throws -> MLDictionaryFeatureProvider {
        let motionData = try MLMultiArray(shape: [1, NSNumber(value: Self.channelCount), NSNumber(value: windowSize)], dataType: .float32)

        for t in 0..<windowSize {
            let sample = samples[t]
            motionData[[0, 0, t] as [NSNumber]] = NSNumber(value: Float(sample.accX))
            motionData[[0, 1, t] as [NSNumber]] = NSNumber(value: Float(sample.accY))
            motionData[[0, 2, t] as [NSNumber]] = NSNumber(value: Float(sample.accZ))
            motionData[[0, 3, t] as [NSNumber]] = NSNumber(value: Float(sample.rotX))
            motionData[[0, 4, t] as [NSNumber]] = NSNumber(value: Float(sample.rotY))
            motionData[[0, 5, t] as [NSNumber]] = NSNumber(value: Float(sample.rotZ))
        }

        return try MLDictionaryFeatureProvider(dictionary: [
            "motionData": MLFeatureValue(multiArray: motionData)
        ])
    }
}
