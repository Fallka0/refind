//
//  RootView.swift
//  refind
//
//  Splash → (sign-in, live mode only) → onboarding → the app.
//
//  Demo mode skips the session gate entirely: it is seeded data with nobody
//  signed in, which is what keeps the app demonstrable without a server.
//

import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    // Seeded from defaults rather than bound with @AppStorage: UI tests set this
    // through the launch-argument domain, which is read-only and outranks any
    // write, so a bound property could never flip and onboarding never ended.
    @State private var onboardingDone =
        UserDefaults.standard.bool(forKey: RootView.onboardingKey)

    @State private var splashDone = false
    @State private var auth: AuthStore?

    var body: some View {
        ZStack {
            if !splashDone {
                SplashScreen()
                    .transition(.opacity)
            } else if let auth, needsSignIn(auth) {
                SignInScreen(store: auth)
                    .transition(.opacity)
            } else if !onboardingDone {
                OnboardingFlow { finishOnboarding() }
                    .transition(.opacity)
            } else {
                TabShell()
                    .transition(.opacity)
            }
        }
        .animation(RF.Motion.entrance, value: splashDone)
        .animation(RF.Motion.entrance, value: onboardingDone)
        .animation(RF.Motion.entrance, value: auth?.state)
        .task {
            await environment.resetSessionIfRequested()
            let store = auth ?? AuthStore(api: environment.api,
                                          repository: environment.repository)
            auth = store
            // Session restore and the splash run together; the splash has a
            // minimum of 900 ms per the handoff, so this usually costs nothing.
            async let restored: Void = restoreIfNeeded(store)
            async let minimum: Void = sleepMinimum()
            _ = await (restored, minimum)
            splashDone = true
        }
    }

    static let onboardingKey = "rf.onboardingDone"

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        onboardingDone = true
    }

    private func needsSignIn(_ auth: AuthStore) -> Bool {
        environment.mode == .live && auth.state == .signedOut
    }

    private func restoreIfNeeded(_ store: AuthStore) async {
        guard environment.mode == .live else { return }
        await store.restore()
    }

    private func sleepMinimum() async {
        try? await Task.sleep(for: .milliseconds(900))
    }
}
