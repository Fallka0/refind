//
//  UITestSupport.swift
//  refindUITests
//

import XCTest

extension XCUIApplication {
    /// Launches straight into the tab shell. The onboarding gate is a
    /// UserDefaults flag, so the argument domain can pre-answer it — no test
    /// hook in the app itself.
    static func launchedIntoApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-rf.onboardingDone", "YES"]
        app.launch()
        return app
    }

    /// Launches with onboarding still pending.
    static func launchedIntoOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-rf.onboardingDone", "NO"]
        app.launch()
        return app
    }
}
