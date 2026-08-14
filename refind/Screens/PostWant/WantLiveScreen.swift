//
//  WantLiveScreen.swift
//  refind
//
//  Screen 06 · Gesuch ist live. Confirmation, no tab bar.
//

import SwiftUI

struct WantLiveScreen: View {
    let want: Want
    let onDone: () -> Void

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                FinMascot(state: .searching, height: 124)

                Text("Dein Gesuch hängt.")
                    .font(RF.display(40))
                    .foregroundStyle(RF.Palette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 54)

                Text("Wir sagen dir Bescheid, sobald jemand ein Angebot schickt. Meist geht das schnell.")
                    .font(RF.ui(15))
                    .foregroundStyle(RF.Palette.inkMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 280)
                    .padding(.top, 16)

                RFCard(padding: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dein Gesuch").rfLabel(10)
                        Text(want.title)
                            .font(RF.display(24))
                            .foregroundStyle(RF.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(summary)
                            .font(RF.num(12, weight: .medium))
                            .foregroundStyle(RF.Palette.inkMid)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .padding(.top, 40)

                Spacer(minLength: 40)

                VStack(spacing: 12) {
                    Button("Zu meinen Gesuchen", action: onDone)
                        .buttonStyle(RFButtonStyle(kind: .primary))
                    ShareLink(item: shareText) {
                        Text("Teilen")
                            .font(RF.ui(16, weight: .medium))
                            .foregroundStyle(RF.Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: RF.Metric.buttonHeight)
                            .overlay { Capsule().strokeBorder(RF.Palette.ink, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 140)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
        .interactiveDismissDisabled()
    }

    private var shareText: String {
        "Ich suche: \(want.title) — \(want.constraintLine). Gefunden auf refind."
    }

    /// "bis CHF 2'000 · Zürich · 14 Tage"
    ///
    /// Rounded, not floored: a want created moments ago with a 14-day duration
    /// is a hair under 14 × 86'400 s by the time this draws, and flooring would
    /// greet the user with "13 Tage" on the screen confirming they chose 14.
    private var summary: String {
        let days = max(0, Int((want.expiresAt.timeIntervalSinceNow / 86_400).rounded()))
        return "bis \(want.budgetMax.formatted) · \(want.region) · \(days) Tage"
    }
}

#Preview("06 Live") {
    WantLiveScreen(want: MockSeed.omegaWant, onDone: {})
}
