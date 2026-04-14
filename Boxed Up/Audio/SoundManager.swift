//
//  SoundManager.swift
//  Boxed Up
//
//  Created on 14/04/26.
//

import AudioToolbox
import UIKit

/// Plays system sound effects for game events on iPhone.
enum SoundManager {

    /// Punch detected — plays a hit sound.
    static func playPunchDetected() {
        AudioServicesPlaySystemSound(1104)  // Tock
    }

    /// Correct punch — plays a positive chime.
    static func playCorrect() {
        AudioServicesPlaySystemSound(1025)  // New Mail
    }

    /// Wrong punch — plays a negative sound.
    static func playWrong() {
        AudioServicesPlaySystemSound(1073)  // VC Ended
    }

    /// Timeout miss — plays a timeout indicator.
    static func playTimeout() {
        AudioServicesPlaySystemSound(1053)  // Tweet Sent
    }

    /// Round complete — plays a completion sound.
    static func playRoundComplete() {
        AudioServicesPlaySystemSound(1026)  // Sent Mail
    }
}
