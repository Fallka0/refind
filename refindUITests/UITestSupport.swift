//
//  UITestSupport.swift
//  refindUITests
//

import XCTest

extension XCUIApplication {
    /// The product is German-first and these tests assert German copy. Pinning
    /// the language keeps them deterministic whatever the simulator is set to —
    /// without it they pass or fail depending on the host's locale.
    static let germanLocale = ["-AppleLanguages", "(de)", "-AppleLocale", "de_CH"]

    /// Launches straight into the tab shell. The onboarding gate is a
    /// UserDefaults flag, so the argument domain can pre-answer it — no test
    /// hook in the app itself.
    static func launchedIntoApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += Self.germanLocale + ["-rf.onboardingDone", "YES"]
        app.launch()
        return app
    }

    /// Launches with onboarding still pending.
    static func launchedIntoOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += Self.germanLocale + ["-rf.onboardingDone", "NO"]
        app.launch()
        return app
    }
}
