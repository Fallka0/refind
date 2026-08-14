//
//  OnboardingUITests.swift
//  refindUITests
//
//  Covers the gate itself: splash → onboarding → tab shell.
//

import XCTest

final class OnboardingUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testOnboardingLeadsIntoTheApp() {
        let app = XCUIApplication.launchedIntoOnboarding()

        // Splash resolves on its own, then step 1.
        XCTAssertTrue(app.staticTexts["Was interessiert dich?"].waitForExistence(timeout: 10),
                      "Onboarding never appeared. Hierarchy:\n\(app.debugDescription)")

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "Weiter should wait for at least one interest")

        app.buttons["Uhren"].firstMatch.tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()

        XCTAssertTrue(app.staticTexts["Wo suchst du?"].waitForExistence(timeout: 5))
        next.tap()

        XCTAssertTrue(app.staticTexts["Bleibst du erreichbar?"].waitForExistence(timeout: 5))
        next.tap()

        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 10),
                      "Onboarding did not hand over to the tab shell")
    }

    func testSkipGoesStraightToTheApp() {
        let app = XCUIApplication.launchedIntoOnboarding()

        XCTAssertTrue(app.buttons["Überspringen"].waitForExistence(timeout: 10))
        app.buttons["Überspringen"].tap()

        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 10))
    }
}
