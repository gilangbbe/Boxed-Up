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

    private struct ModelSet {
        let classifier: MLModel
        let detector: MLModel
    }

    private static let leftClassifierName = "PunchClassifier_CNN_leftWatch"
    private static let leftDetectorName = "PunchDetector_CNN_leftWatch"
    private static let rightClassifierName = "PunchClassifier_CNN_rightGlove"
    private static let rightDetectorName = "PunchDetector_CNN_rightGlove"
    private static let fallbackClassifierName = "PunchClassifier_CNN"
    private static let fallbackDetectorName = "PunchDetector_CNN"

    private let classifierModel: MLModel
    private let detectorModel: MLModel
    private let modelsByHand: [HandSide: ModelSet]

    static let classifierWindowSize = 50  // 1.0s at 50 Hz
    static let detectorWindowSize = 25    // 0.5s at 50 Hz
    private static let channelCount = 6   // accX, accY, accZ, rotX, rotY, rotZ

    init?() {
        guard let fallbackClassifierURL = Bundle.main.url(forResource: Self.fallbackClassifierName, withExtension: "mlmodelc"),
              let fallbackDetectorURL = Bundle.main.url(forResource: Self.fallbackDetectorName, withExtension: "mlmodelc") else {
            print("[PunchClassifierService] CNN model files not found in bundle")
            return nil
        }

        do {
            classifierModel = try MLModel(contentsOf: fallbackClassifierURL)
            detectorModel = try MLModel(contentsOf: fallbackDetectorURL)

            var handModels: [HandSide: ModelSet] = [:]
            handModels[.left] = try Self.loadModelSet(
                classifierName: Self.leftClassifierName,
                detectorName: Self.leftDetectorName,
                fallbackClassifier: classifierModel,
                fallbackDetector: detectorModel,
                hand: .left
            )
            handModels[.right] = try Self.loadModelSet(
                classifierName: Self.rightClassifierName,
                detectorName: Self.rightDetectorName,
                fallbackClassifier: classifierModel,
                fallbackDetector: detectorModel,
                hand: .right
            )
            modelsByHand = handModels
        } catch {
            print("[PunchClassifierService] Failed to load models: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Detection (Stage 1)

    /// Returns true if the motion window looks like a punch.
    func detectPunch(from samples: [MotionSample]) -> (isPunch: Bool, confidence: Double) {
        detectPunch(from: samples, using: detectorModel)
    }

    /// Returns true if the motion window looks like a punch for the specified hand model.
    func detectPunch(from samples: [MotionSample], hand: HandSide) -> (isPunch: Bool, confidence: Double) {
        detectPunch(from: samples, using: modelSet(for: hand).detector)
    }

    private func detectPunch(from samples: [MotionSample], using detector: MLModel) -> (isPunch: Bool, confidence: Double) {
        let windowSize = Self.detectorWindowSize
        guard samples.count >= windowSize else { return (false, 0) }

        let window = Array(samples.suffix(windowSize))

        do {
            let input = try buildCNNInput(samples: window, windowSize: windowSize)
            let output = try detector.prediction(from: input)

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
        classifyPunch(from: samples, using: classifierModel)
    }

    /// Classifies the punch type from a motion window for the specified hand model.
    func classifyPunch(from samples: [MotionSample], hand: HandSide) -> (punchType: PunchType, confidence: Double) {
        classifyPunch(from: samples, using: modelSet(for: hand).classifier)
    }

    private func classifyPunch(from samples: [MotionSample], using classifier: MLModel) -> (punchType: PunchType, confidence: Double) {
        let windowSize = Self.classifierWindowSize
        guard samples.count >= windowSize else {
            return (.jab, 0)
        }

        let window = Array(samples.suffix(windowSize))

        do {
            let input = try buildCNNInput(samples: window, windowSize: windowSize)
            let output = try classifier.prediction(from: input)

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

    private func modelSet(for hand: HandSide) -> ModelSet {
        modelsByHand[hand] ?? ModelSet(classifier: classifierModel, detector: detectorModel)
    }

    private static func loadModelSet(
        classifierName: String,
        detectorName: String,
        fallbackClassifier: MLModel,
        fallbackDetector: MLModel,
        hand: HandSide
    ) throws -> ModelSet {
        guard let classifierURL = Bundle.main.url(forResource: classifierName, withExtension: "mlmodelc"),
              let detectorURL = Bundle.main.url(forResource: detectorName, withExtension: "mlmodelc") else {
            print("[PunchClassifierService] Hand-specific models for \(hand.rawValue) not found, using fallback CNN models")
            return ModelSet(classifier: fallbackClassifier, detector: fallbackDetector)
        }

        return ModelSet(
            classifier: try MLModel(contentsOf: classifierURL),
            detector: try MLModel(contentsOf: detectorURL)
        )
    }
}
