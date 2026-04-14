//
//  PunchClassifier.swift
//  Boxed Up
//
//  Created on 14/04/26.
//

import CoreML
import Foundation

/// Wraps the PunchClassifier and PunchDetector Core ML models for real-time inference.
/// Two-stage pipeline: Detector checks if motion is a punch → Classifier identifies punch type.
class PunchClassifierService {

    private let classifierModel: MLModel
    private let detectorModel: MLModel

    private var classifierState: MLMultiArray
    private var detectorState: MLMultiArray

    static let classifierWindowSize = 50  // 1.0s at 50 Hz
    static let detectorWindowSize = 25    // 0.5s at 50 Hz
    private static let stateSize = 400

    init?() {
        guard let classifierURL = Bundle.main.url(forResource: "PunchClassifier", withExtension: "mlmodelc"),
              let detectorURL = Bundle.main.url(forResource: "PunchDetector", withExtension: "mlmodelc") else {
            print("[PunchClassifier] Model files not found in bundle")
            return nil
        }

        do {
            classifierModel = try MLModel(contentsOf: classifierURL)
            detectorModel = try MLModel(contentsOf: detectorURL)
            classifierState = try MLMultiArray(shape: [NSNumber(value: Self.stateSize)], dataType: .double)
            detectorState = try MLMultiArray(shape: [NSNumber(value: Self.stateSize)], dataType: .double)
        } catch {
            print("[PunchClassifier] Failed to load models: \(error.localizedDescription)")
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
            let input = try buildFeatureProvider(samples: window, windowSize: windowSize, state: detectorState)
            let output = try detectorModel.prediction(from: input)

            // Update recurrent state
            if let newState = output.featureValue(for: "stateOut")?.multiArrayValue {
                detectorState = newState
            }

            let label = output.featureValue(for: "label")?.stringValue ?? "other"
            let probs = output.featureValue(for: "labelProbability")?.dictionaryValue as? [String: Double] ?? [:]
            let punchConfidence = probs["punch"] ?? 0

            return (label == "punch", punchConfidence)
        } catch {
            print("[PunchClassifier] Detection error: \(error.localizedDescription)")
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
            let input = try buildFeatureProvider(samples: window, windowSize: windowSize, state: classifierState)
            let output = try classifierModel.prediction(from: input)

            // Update recurrent state
            if let newState = output.featureValue(for: "stateOut")?.multiArrayValue {
                classifierState = newState
            }

            let label = output.featureValue(for: "label")?.stringValue ?? "jab"
            let probs = output.featureValue(for: "labelProbability")?.dictionaryValue as? [String: Double] ?? [:]
            let confidence = probs[label] ?? 0

            let punchType = PunchType(rawValue: label) ?? .jab
            return (punchType, confidence)
        } catch {
            print("[PunchClassifier] Classification error: \(error.localizedDescription)")
            return (.jab, 0)
        }
    }

    /// Resets recurrent state (call between rounds).
    func resetState() {
        classifierState = (try? MLMultiArray(shape: [NSNumber(value: Self.stateSize)], dataType: .double)) ?? classifierState
        detectorState = (try? MLMultiArray(shape: [NSNumber(value: Self.stateSize)], dataType: .double)) ?? detectorState
    }

    // MARK: - Feature Provider

    private func buildFeatureProvider(samples: [MotionSample], windowSize: Int, state: MLMultiArray) throws -> MLDictionaryFeatureProvider {
        let accX = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .double)
        let accY = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .double)
        let accZ = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .double)
        let rotX = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .double)
        let rotY = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .double)
        let rotZ = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .double)

        for i in 0..<windowSize {
            let sample = samples[i]
            accX[i] = NSNumber(value: sample.accX)
            accY[i] = NSNumber(value: sample.accY)
            accZ[i] = NSNumber(value: sample.accZ)
            rotX[i] = NSNumber(value: sample.rotX)
            rotY[i] = NSNumber(value: sample.rotY)
            rotZ[i] = NSNumber(value: sample.rotZ)
        }

        return try MLDictionaryFeatureProvider(dictionary: [
            "accX": MLFeatureValue(multiArray: accX),
            "accY": MLFeatureValue(multiArray: accY),
            "accZ": MLFeatureValue(multiArray: accZ),
            "rotX": MLFeatureValue(multiArray: rotX),
            "rotY": MLFeatureValue(multiArray: rotY),
            "rotZ": MLFeatureValue(multiArray: rotZ),
            "stateIn": MLFeatureValue(multiArray: state)
        ])
    }
}
