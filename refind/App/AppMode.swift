//
//  AppMode.swift
//  refind
//
//  Which repository the app runs against. The seeded demo is kept — it is what
//  makes the app demonstrable without a server, and it backs every preview and
//  test — but it is now an explicit choice rather than the only option.
//

import SwiftUI

enum AppMode: String, CaseIterable, Identifiable, Sendable {
    /// Seeded in-memory data. No network.
    case demo
    /// The real API in docs/API.md.
    case live

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .demo: return String(localized: "Demo")
        case .live: return String(localized: "Live")
        }
    }

    /// Demo until a backend is actually serving; flip the default here when it is.
    static let `default`: AppMode = .demo

    static var current: AppMode {
        // A launch argument wins, so tests and the debug hatch can pin a mode.
        if let raw = ProcessInfo.processInfo.environment["RF_MODE"],
           let mode = AppMode(rawValue: raw) {
            return mode
        }
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let mode = AppMode(rawValue: raw) {
            return mode
        }
        return .default
    }

    static let storageKey = "rf.mode"
}

extension AppEnvironment {
    /// Builds the repository for a mode. One place decides this.
    static func repository(for mode: AppMode) -> any RefindRepository {
        switch mode {
        case .demo: return MockRefindRepository.demo
        case .live: return LiveRefindRepository()
        }
    }
}
