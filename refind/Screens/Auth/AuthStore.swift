//
//  AuthStore.swift
//  refind
//
//  Session state for the live mode. Demo mode has no session — it is seeded
//  data with nobody signed in — so the gate only applies when running live.
//

import SwiftUI

@MainActor
@Observable
final class AuthStore {

    enum State: Equatable {
        case checking
        case signedOut
        case signedIn(User)
    }

    var state: State = .checking
    var email = ""
    var password = ""
    var displayName = ""
    var isRegistering = false
    var isWorking = false
    var errorMessage: String?

    private let api: RefindAPI
    private let repository: any RefindRepository

    init(api: RefindAPI, repository: any RefindRepository) {
        self.api = api
        self.repository = repository
    }

    /// A stored refresh token is the only durable thing; the access token is
    /// short-lived, so restoring a session means proving the refresh still works.
    func restore() async {
        guard await api.hasStoredSession() else {
            state = .signedOut
            return
        }
        do {
            state = .signedIn(try await repository.currentUser())
        } catch {
            // Expired or revoked — start clean rather than sit in a broken session.
            await api.clearSession()
            state = .signedOut
        }
    }

    var canSubmit: Bool {
        !isWorking
            && email.contains("@")
            && password.count >= 8
    }

    func submit() async {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            if isRegistering {
                try await api.register(email: email, password: password,
                                       displayName: displayName.isEmpty ? nil : displayName)
            } else {
                try await api.login(email: email, password: password)
            }
            state = .signedIn(try await repository.currentUser())
            password = ""
        } catch {
            errorMessage = (error as? RepositoryError)?.inlineMessage
                ?? RepositoryError.server.inlineMessage
        }
    }

    func signOut() async {
        await api.signOut()
        state = .signedOut
        email = ""
        password = ""
    }

    /// Copy that matches the mode rather than a generic "sign in".
    var title: String {
        isRegistering
            ? String(localized: "Konto erstellen")
            : String(localized: "Willkommen zurück")
    }

    var actionTitle: String {
        if isWorking { return String(localized: "Einen Moment …") }
        return isRegistering
            ? String(localized: "Konto erstellen")
            : String(localized: "Anmelden")
    }

    var switchTitle: String {
        isRegistering
            ? String(localized: "Ich habe schon ein Konto")
            : String(localized: "Neu hier? Konto erstellen")
    }
}
