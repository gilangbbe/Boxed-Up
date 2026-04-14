//
//  WatchSessionManager.swift
//  Boxed Up (iOS)
//
//  Created on 13/04/26.
//

import Foundation
import WatchConnectivity

/// iPhone-side WCSession manager. Receives motion data from Watch, sends game commands.
@Observable
class PhoneSessionManager: NSObject {

    private(set) var isWatchReachable: Bool = false
    private(set) var isSessionActivated: Bool = false

    /// Called when motion samples arrive from Watch.
    var onMotionData: (([MotionSample]) -> Void)?
    /// Called when Watch signals motion started/stopped.
    var onMotionLifecycle: ((Bool) -> Void)?
    /// Called when Watch reachability changes (true = reachable, false = disconnected).
    var onReachabilityChanged: ((Bool) -> Void)?

    private var session: WCSession {
        WCSession.default
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - Send to Watch

    func send(_ message: WatchMessage) {
        guard session.isReachable else { return }
        session.sendMessage(message.toDictionary(), replyHandler: nil) { error in
            print("[PhoneSession] Send error: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
            self.isSessionActivated = activationState == .activated
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.isSessionActivated = false
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.isSessionActivated = false
        }
        // Re-activate for future sessions
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            self.onReachabilityChanged?(session.isReachable)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let watchMessage = WatchMessage.from(message) else { return }

        switch watchMessage {
        case .motionData(let samples):
            onMotionData?(samples)
        case .motionStarted:
            onMotionLifecycle?(true)
        case .motionStopped:
            onMotionLifecycle?(false)
        default:
            break
        }
    }
}
