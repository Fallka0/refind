//
//  PostWantFlowUITests.swift
//  refindUITests
//
//  Drives 04 → 05 → review → 06 and back to Home, which is the only way to
//  verify the flow actually connects — a screenshot cannot.
//

import XCTest

final class PostWantFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testPostingAWantPutsItOnHome() {
        let app = XCUIApplication.launchedIntoApp()

        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 10))

        // Home → step 1
        let post = app.buttons["Gesuch aufhängen"].firstMatch
        XCTAssertTrue(post.waitForExistence(timeout: 5),
                      "No post button. Hierarchy:\n\(app.debugDescription)")
        post.tap()

        // Step 1 · title
        XCTAssertTrue(app.staticTexts["Was suchst du?"].waitForExistence(timeout: 5))
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Braun SK 4 Schneewittchensarg")

        app.buttons["post.title.next"].tap()

        // Step 2 · details
        XCTAssertTrue(app.staticTexts["Wie viel, welcher Zustand?"].waitForExistence(timeout: 5))
        // Condition is single-select; pick a non-default one.
        app.buttons["Serviciert"].firstMatch.tap()
        app.buttons["post.details.next"].tap()

        // Step 3 · review
        XCTAssertTrue(app.staticTexts["Passt das so?"].waitForExistence(timeout: 5))
        app.buttons["post.submit"].tap()

        // Screen 06 · live
        XCTAssertTrue(app.staticTexts["Dein Gesuch hängt."].waitForExistence(timeout: 10),
                      "Never reached the confirmation screen")
        app.buttons["Zu meinen Gesuchen"].tap()

        // Back on Home, with the new want at the top.
        XCTAssertTrue(app.staticTexts["Braun SK 4 Schneewittchensarg"]
            .waitForExistence(timeout: 10),
                      "New want did not appear on Home")
    }

    /// The budget is typed, not only dragged.
    func testBudgetCanBeTyped() {
        let app = XCUIApplication.launchedIntoApp()

        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 10))
        app.buttons["Gesuch aufhängen"].firstMatch.tap()

        let title = app.textFields.firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Braun SK 4")
        app.buttons["post.title.next"].tap()

        XCTAssertTrue(app.staticTexts["Wie viel, welcher Zustand?"].waitForExistence(timeout: 5))

        let budget = app.textFields["Budget in Franken"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5),
                      "Budget is not a text field. Hierarchy:\n\(app.debugDescription)")
        // Focusing clears the seeded amount, so this is a fresh entry — an
        // amount a 50-franc-step slider would fight you for.
        budget.tap()
        budget.typeText("2350")

        XCTAssertTrue(app.textFields["Budget in Franken"].value as? String == "2’350"
                      || (app.textFields["Budget in Franken"].value as? String)?
                          .contains("350") == true,
                      "Typed budget did not stick: \(String(describing: app.textFields["Budget in Franken"].value))")

        app.buttons["post.details.next"].tap()
        XCTAssertTrue(app.staticTexts["Passt das so?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "2’350")).firstMatch.exists,
                      "Review step lost the typed budget")
    }

    func testCancelLeavesHomeUnchanged() {
        let app = XCUIApplication.launchedIntoApp()

        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 10))
        let before = app.staticTexts["Omega Seamaster 166.062"].exists

        app.buttons["Gesuch aufhängen"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Was suchst du?"].waitForExistence(timeout: 5))
        app.buttons["Abbrechen"].tap()

        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["Omega Seamaster 166.062"].exists, before)
    }

    /// "Weiter" stays disabled until the title clears three characters.
    func testTitleValidationGatesTheFirstStep() {
        let app = XCUIApplication.launchedIntoApp()

        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 10))
        app.buttons["Gesuch aufhängen"].firstMatch.tap()

        let next = app.buttons["post.title.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "Weiter should be disabled with an empty title")

        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("Om")
        XCTAssertFalse(next.isEnabled, "Weiter should still be disabled at two characters")

        field.typeText("ega")
        XCTAssertTrue(next.isEnabled, "Weiter should enable once the title is valid")
    }
}
