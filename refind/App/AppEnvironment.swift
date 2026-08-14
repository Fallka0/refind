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
    let repository: any RefindRepository
    var currentUser: User?

    init(repository: any RefindRepository = MockRefindRepository.demo) {
        self.repository = repository
    }

    func loadSession() async {
        currentUser = try? await repository.currentUser()
    }

    /// Previews and tests: content lands immediately, no skeletons.
    static var preview: AppEnvironment {
        let env = AppEnvironment(repository: MockRefindRepository.instant)
        env.currentUser = MockSeed.me
        return env
    }
}
