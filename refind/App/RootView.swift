//
//  RootView.swift
//  refind
//
//  Splash → onboarding → the tab shell.
//

import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("rf.onboardingDone") private var onboardingDone = false
    @State private var phase: Phase = .splash

    private enum Phase { case splash, onboarding, app }

    /// The splash holds until the session resolves, but never less than this.
    private static let minimumSplash: Duration = .milliseconds(900)

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashScreen()
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlow {
                    onboardingDone = true
                    withAnimation(RF.Motion.entrance) { phase = .app }
                }
                .transition(.opacity)
            case .app:
                TabShell()
                    .transition(.opacity)
            }
        }
        .task {
            async let session: Void = environment.loadSession()
            async let floor: Void = Task.sleep(for: Self.minimumSplash)
            _ = await (session, try? floor)
            withAnimation(RF.Motion.entrance) {
                phase = onboardingDone ? .app : .onboarding
            }
        }
    }
}

#Preview("Root") {
    RootView().environment(AppEnvironment.preview)
}
