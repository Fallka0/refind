//
//  LiveAuthUITests.swift
//  refindUITests
//
//  End to end against a real server: the app registers over HTTP, the row
//  lands in Postgres, and Home renders whatever comes back.
//
//  Needs the API running (see server/README.md). Skipped when it is not, so a
//  plain `xcodebuild test` on a machine without the backend stays green.
//

import XCTest

final class LiveAuthUITests: XCTestCase {

    private let base = URL(string: "http://localhost:3000")!

    override func setUp() {
        continueAfterFailure = false
    }

    /// The suite is only meaningful with a server; report it as skipped, not passed.
    private func requireServer() throws {
        let expectation = expectation(description: "health")
        var reachable = false
        URLSession.shared.dataTask(with: base.appending(path: "health")) { _, response, _ in
            reachable = (response as? HTTPURLResponse)?.statusCode == 200
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 5)
        try XCTSkipUnless(reachable, "No API on \(base). Start it: cd server && npm run dev")
    }

    func testRegisterOnLiveServerReachesTheApp() throws {
        try requireServer()

        let app = XCUIApplication()
        app.launchEnvironment["RF_MODE"] = "live"
        app.launchArguments += XCUIApplication.germanLocale
            + ["-rf.onboardingDone", "YES", "-rf.resetSession", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Willkommen zurück"].waitForExistence(timeout: 15),
                      "Live mode did not gate on sign-in. Hierarchy:\n\(app.debugDescription)")

        app.buttons["auth.switch"].tap()
        XCTAssertTrue(app.staticTexts["Konto erstellen"].waitForExistence(timeout: 5))

        let fields = app.textFields
        XCTAssertTrue(fields.element(boundBy: 0).waitForExistence(timeout: 5))

        // Name, then e-mail — a fresh address so the run is repeatable.
        fields.element(boundBy: 0).tap()
        fields.element(boundBy: 0).typeText("Testperson")

        fields.element(boundBy: 1).tap()
        fields.element(boundBy: 1).typeText("ui-\(Int(Date().timeIntervalSince1970))@refind.ch")

        app.secureTextFields.firstMatch.tap()
        dismissStrongPasswordSheet(app)
        app.secureTextFields.firstMatch.typeText("correct-horse-battery")

        app.buttons["auth.submit"].tap()

        // Signed in: the tab shell, and Home showing the real (empty) account.
        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 20),
                      "Registration did not reach the app. Hierarchy:\n\(app.debugDescription)")
        XCTAssertTrue(
            app.staticTexts["Noch kein Gesuch. Häng eines auf – andere melden sich bei dir."]
                .waitForExistence(timeout: 15),
            "A brand-new account should show the empty state, not seeded demo data"
        )
    }

    /// `.textContentType(.newPassword)` makes iOS offer a generated password.
    /// That is the right behaviour for a real user and the wrong one for a
    /// scripted one, so the test dismisses it rather than the field dropping
    /// the trait.
    private func dismissStrongPasswordSheet(_ app: XCUIApplication) {
        let close = app.buttons["Schließen"]
        if close.waitForExistence(timeout: 3) {
            close.tap()
        }
    }

    /// Real data, not the seed: this account's wants exist only in Postgres.
    func testSignInShowsWantsFromTheServer() throws {
        try requireServer()
        try seedAccountIfNeeded()

        let app = XCUIApplication()
        app.launchEnvironment["RF_MODE"] = "live"
        app.launchArguments += XCUIApplication.germanLocale
            + ["-rf.onboardingDone", "YES", "-rf.resetSession", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Willkommen zurück"].waitForExistence(timeout: 15))

        let email = app.textFields.firstMatch
        email.tap()
        email.typeText(Self.seedEmail)

        app.secureTextFields.firstMatch.tap()
        dismissStrongPasswordSheet(app)
        app.secureTextFields.firstMatch.typeText(Self.seedPassword)

        app.buttons["auth.submit"].tap()

        XCTAssertTrue(app.buttons["Gesuche"].waitForExistence(timeout: 20),
                      "Sign-in did not reach the app")
        XCTAssertTrue(app.staticTexts["Omega Seamaster 166.062"].waitForExistence(timeout: 15),
                      "Home did not render the want that exists only on the server. "
                      + "Hierarchy:\n\(app.debugDescription)")
        // Proves it is not the seeded demo — the mock's Omega has 4 offers and
        // this one, created over HTTP, has none.
        XCTAssertFalse(app.staticTexts["4 neue Angebote"].exists,
                       "That looks like the seeded demo data, not the server's")
    }

    private static let seedEmail = "uitest-fixture@refind.ch"
    private static let seedPassword = "correct-horse-battery"

    /// Creates the fixture account and its want through the API, so the test
    /// asserts on data the app could only have fetched.
    private func seedAccountIfNeeded() throws {
        func post(_ path: String, _ body: [String: Any], token: String? = nil) -> [String: Any]? {
            var request = URLRequest(url: base.appending(path: path))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            var result: [String: Any]?
            let done = expectation(description: path)
            URLSession.shared.dataTask(with: request) { data, _, _ in
                result = data.flatMap {
                    try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
                } ?? nil
                done.fulfill()
            }.resume()
            wait(for: [done], timeout: 15)
            return result
        }

        let credentials: [String: Any] = [
            "email": Self.seedEmail, "password": Self.seedPassword, "displayName": "UI Fixture",
        ]
        // Register, or log in when a previous run already created it.
        let session = post("v1/auth/register", credentials)
            ?? post("v1/auth/login", credentials)
        guard let token = (session?["accessToken"] as? String)
                ?? (post("v1/auth/login", credentials)?["accessToken"] as? String) else {
            throw XCTSkip("Could not obtain a token for the fixture account")
        }
        _ = post("v1/wants", [
            "title": "Omega Seamaster 166.062",
            "category": "uhren",
            "budgetMax": ["minorUnits": 200_000],
            "condition": "original",
            "region": "Zürich",
            "radiusKm": 30,
            "durationDays": 14,
        ], token: token)
    }

    /// Wrong credentials must surface the server's own German message.
    func testWrongPasswordShowsTheServerMessage() throws {
        try requireServer()

        let app = XCUIApplication()
        app.launchEnvironment["RF_MODE"] = "live"
        app.launchArguments += XCUIApplication.germanLocale
            + ["-rf.onboardingDone", "YES", "-rf.resetSession", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Willkommen zurück"].waitForExistence(timeout: 15))

        let email = app.textFields.firstMatch
        email.tap()
        email.typeText("nobody-\(Int(Date().timeIntervalSince1970))@refind.ch")

        app.secureTextFields.firstMatch.tap()
        app.secureTextFields.firstMatch.typeText("definitely-wrong-password")

        app.buttons["auth.submit"].tap()

        XCTAssertTrue(
            app.staticTexts["E-MAIL ODER PASSWORT STIMMT NICHT."].waitForExistence(timeout: 15),
            "Expected the server's message. Hierarchy:\n\(app.debugDescription)"
        )
        XCTAssertFalse(app.buttons["Gesuche"].exists, "A failed sign-in must not enter the app")
    }
}
