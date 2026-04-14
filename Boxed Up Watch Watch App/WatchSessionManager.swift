//
//  WatchSessionManager.swift
//  Boxed Up Watch Watch App
//
//  Created on 13/04/26.
//

import Foundation
import WatchConnectivity

/// Watch-side WCSession manager. Sends motion data to iPhone, receives game commands.
@Observable
class WatchSessionManager: NSObject {

    private(set) var isPhoneReachable: Bool = false
    private(set) var isSessionActivated: Bool = false

    /// Called when iPhone sends a game state update.
    var onGameState: ((GameAction) -> Void)?
    /// Called when iPhone sends punch detection result (for haptic feedback).
    var onPunchDetected: ((PunchType, Bool) -> Void)?
    /// Called when iPhone requests to start/stop motion capture.
    var onCaptureControl: ((Bool) -> Void)?
    /// Called when round starts/ends.
    var onRoundLifecycle: ((Bool) -> Void)?
    /// Called when iPhone enters/exits data collection mode.
    var onDataCollectionMode: ((Bool) -> Void)?
    /// Called when iPhone reachability changes.
    var onReachabilityChanged: ((Bool) -> Void)?

    private var session: WCSession {
        WCSession.default
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - Send to iPhone

    func send(_ message: WatchMessage) {
        guard session.isReachable else { return }
        session.sendMessage(message.toDictionary(), replyHandler: nil) { error in
            print("[WatchSession] Send error: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
            self.isSessionActivated = activationState == .activated
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            self.onReachabilityChanged?(session.isReachable)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let watchMessage = WatchMessage.from(message) else { return }

        switch watchMessage {
        case .startCapture:
            onCaptureControl?(true)
        case .stopCapture:
            onCaptureControl?(false)
        case .punchDetected(let punch, let correct):
            onPunchDetected?(punch, correct)
        case .gameState(let action):
            onGameState?(action)
        case .roundStart:
            onRoundLifecycle?(true)
        case .roundEnd:
            onRoundLifecycle?(false)
        case .enterDataCollection:
            onDataCollectionMode?(true)
        case .exitDataCollection:
            onDataCollectionMode?(false)
        default:
            break
        }
    }
}
