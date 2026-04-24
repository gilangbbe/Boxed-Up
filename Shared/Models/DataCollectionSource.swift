//
//  DataCollectionSource.swift
//  Boxed Up
//
//  Created on 23/04/26.
//

import Foundation

/// Motion source selection for training data collection.
/// Smart Glove is fixed on the right hand.
enum DataCollectionSource: String, CaseIterable, Codable {
    case leftWatch
    case rightGlove
    case both

    static let physicalSources: [DataCollectionSource] = [.leftWatch, .rightGlove]

    var displayName: String {
        switch self {
        case .leftWatch:
            return "Left (Watch)"
        case .rightGlove:
            return "Right (Smart Glove)"
        case .both:
            return "Both Hands"
        }
    }

    var shortName: String {
        switch self {
        case .leftWatch:
            return "L"
        case .rightGlove:
            return "R"
        case .both:
            return "L+R"
        }
    }

    var directoryName: String {
        switch self {
        case .leftWatch:
            return "left_watch"
        case .rightGlove:
            return "right_glove"
        case .both:
            return "both"
        }
    }

    var includesWatch: Bool {
        self == .leftWatch || self == .both
    }

    var includesGlove: Bool {
        self == .rightGlove || self == .both
    }
}
