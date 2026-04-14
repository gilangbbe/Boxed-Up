//
//  WatchMessage.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import Foundation

/// Messages exchanged between Watch and iPhone via WatchConnectivity.
/// Encoded/decoded as dictionaries for WCSession.sendMessage.
enum WatchMessage {
    // MARK: - Watch → iPhone
    case motionData([MotionSample])
    case motionStarted
    case motionStopped

    // MARK: - iPhone → Watch
    case startCapture
    case stopCapture
    case punchDetected(PunchType, correct: Bool)
    case gameState(GameAction)
    case roundStart
    case roundEnd
    case enterDataCollection
    case exitDataCollection

    // MARK: - Dictionary Keys
    private enum Keys {
        static let type = "type"
        static let samples = "samples"
        static let punchType = "punchType"
        static let correct = "correct"
        static let action = "action"
    }

    // MARK: - Encode to Dictionary

    func toDictionary() -> [String: Any] {
        switch self {
        case .motionData(let samples):
            let encoded = (try? JSONEncoder().encode(samples)) ?? Data()
            return [Keys.type: "motionData", Keys.samples: encoded]
        case .motionStarted:
            return [Keys.type: "motionStarted"]
        case .motionStopped:
            return [Keys.type: "motionStopped"]
        case .startCapture:
            return [Keys.type: "startCapture"]
        case .stopCapture:
            return [Keys.type: "stopCapture"]
        case .punchDetected(let punch, let correct):
            return [Keys.type: "punchDetected", Keys.punchType: punch.rawValue, Keys.correct: correct]
        case .gameState(let action):
            return [Keys.type: "gameState", Keys.action: action.rawValue]
        case .roundStart:
            return [Keys.type: "roundStart"]
        case .roundEnd:
            return [Keys.type: "roundEnd"]
        case .enterDataCollection:
            return [Keys.type: "enterDataCollection"]
        case .exitDataCollection:
            return [Keys.type: "exitDataCollection"]
        }
    }

    // MARK: - Decode from Dictionary

    static func from(_ dictionary: [String: Any]) -> WatchMessage? {
        guard let type = dictionary[Keys.type] as? String else { return nil }

        switch type {
        case "motionData":
            guard let data = dictionary[Keys.samples] as? Data,
                  let samples = try? JSONDecoder().decode([MotionSample].self, from: data) else { return nil }
            return .motionData(samples)
        case "motionStarted":
            return .motionStarted
        case "motionStopped":
            return .motionStopped
        case "startCapture":
            return .startCapture
        case "stopCapture":
            return .stopCapture
        case "punchDetected":
            guard let rawPunch = dictionary[Keys.punchType] as? String,
                  let punch = PunchType(rawValue: rawPunch),
                  let correct = dictionary[Keys.correct] as? Bool else { return nil }
            return .punchDetected(punch, correct: correct)
        case "gameState":
            guard let rawAction = dictionary[Keys.action] as? String,
                  let action = GameAction(rawValue: rawAction) else { return nil }
            return .gameState(action)
        case "roundStart":
            return .roundStart
        case "roundEnd":
            return .roundEnd
        case "enterDataCollection":
            return .enterDataCollection
        case "exitDataCollection":
            return .exitDataCollection
        default:
            return nil
        }
    }
}
