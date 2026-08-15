//
//  AppEnvironment.swift
//  refind
//
//  What every screen reaches for: the repository and the signed-in user.
//  Swapping MockRefindRepository for a live one happens here and nowhere else.
//

import SwiftUI

@MainActor
@Observable
final class AppEnvironment {
    let mode: AppMode
    let repository: any RefindRepository
    /// Only meaningful in live mode; harmless otherwise.
    let api: RefindAPI
    var currentUser: User?
    var verification: VerificationStatus = .unverified
    // Not lazy: @Observable rewrites stored properties into init accessors,
    // which lazy cannot participate in.
    let push: PushRegistrar

    init(mode: AppMode = .current, repository: (any RefindRepository)? = nil) {
        let api = RefindAPI()
        self.mode = mode
        self.api = api
        let resolved = repository ?? (mode == .live
            ? LiveRefindRepository(api: api)
            : MockRefindRepository.demo)
        self.repository = resolved
        self.push = PushRegistrar(repository: resolved)
    }

    /// UI tests need a signed-out start, and the Keychain deliberately outlives
    /// the app container — reinstalling does not clear it. This is the only
    /// hook the app exposes for that.
    func resetSessionIfRequested() async {
        guard UserDefaults.standard.bool(forKey: "rf.resetSession") else { return }
        await api.clearSession()
    }

    func loadSession() async {
        currentUser = try? await repository.currentUser()
        verification = (try? await repository.verificationStatus()) ?? .unverified
        AppDelegate.registrar = push
        await push.refreshAuthorization()
    }

    /// Previews and tests: content lands immediately, no skeletons.
    static var preview: AppEnvironment {
        let env = AppEnvironment(mode: .demo, repository: MockRefindRepository.instant)
        env.currentUser = MockSeed.me
        return env
    }
}
