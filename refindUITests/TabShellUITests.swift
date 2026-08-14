//
//  TabShellUITests.swift
//  refindUITests
//
//  Asserts selection only — no placeholder copy — so this keeps working once
//  the real screens replace PlaceholderScreen.
//

import XCTest

final class TabShellUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testEachTabSelects() {
        let app = XCUIApplication.launchedIntoApp()

        let titles = ["Gesuche", "Entdecken", "Chat", "Profil"]

        // Gesuche is the landing tab.
        guard app.buttons["Gesuche"].waitForExistence(timeout: 10) else {
            return XCTFail("No 'Gesuche' button. Hierarchy:\n\(app.debugDescription)")
        }
        XCTAssertTrue(app.buttons["Gesuche"].isSelected)

        for title in titles {
            let tab = app.buttons[title]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab \(title) is missing")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "Tab \(title) did not become selected")

            for other in titles where other != title {
                XCTAssertFalse(app.buttons[other].isSelected,
                               "Tab \(other) stayed selected alongside \(title)")
            }
        }
    }

    /// The tab targets are 44 pt — the handoff calls this out explicitly.
    func testTabTargetsMeetMinimumHitSize() {
        let app = XCUIApplication.launchedIntoApp()

        for title in ["Gesuche", "Entdecken", "Chat", "Profil"] {
            let tab = app.buttons[title]
            XCTAssertTrue(tab.waitForExistence(timeout: 10))
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44,
                                        "Tab \(title) is shorter than 44 pt")
        }
    }
}
