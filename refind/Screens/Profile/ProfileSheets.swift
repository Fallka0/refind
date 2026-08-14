//
//  ProfileSheets.swift
//  refind
//
//  The four Konto rows. None of these are drawn in the handoff — Zahlungsarten,
//  Benachrichtigungen and Suchradius are built plainly from existing pieces,
//  and Verifizierung says what it is: not built yet.
//

import SwiftUI

enum ProfileRoute: String, Identifiable {
    case payment, notifications, radius, verification, blocked
    var id: String { rawValue }
}

struct ProfileSheet: View {
    let route: ProfileRoute
    @Binding var radiusKm: Int
    @Environment(\.dismiss) private var dismiss

    @AppStorage("rf.notify.offers") private var notifyOffers = true
    @AppStorage("rf.notify.messages") private var notifyMessages = true
    @AppStorage("rf.notify.expiry") private var notifyExpiry = false

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(RF.display(32))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                content.padding(.top, 26)

                Spacer(minLength: 24)

                Button("Schliessen") { dismiss() }
                    .buttonStyle(RFButtonStyle(kind: .secondary))
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 34)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(RF.Metric.sheetRadius)
        .presentationBackground(RF.Palette.paper)
    }

    private var title: String {
        switch route {
        case .payment:       return "Zahlungsarten"
        case .notifications: return "Benachrichtigungen"
        case .radius:        return "Suchradius"
        case .verification:  return "Verifizierung"
        case .blocked:       return "Blockiert"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .payment:
            VStack(alignment: .leading, spacing: 12) {
                RFCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Visa · 4242").font(RF.num(15, weight: .medium))
                                .foregroundStyle(RF.Palette.ink)
                            Text("Gespeichert für Treuhand-Zahlungen").rfLabel(10)
                        }
                        Spacer()
                    }
                }
                Text("Mock · keine echten Karten hinterlegt").rfLabel(9, tracking: 0.9)
            }

        case .notifications:
            VStack(spacing: 0) {
                toggleRow("Neue Angebote", isOn: $notifyOffers)
                toggleRow("Chat-Nachrichten", isOn: $notifyMessages)
                toggleRow("Gesuch läuft ab", isOn: $notifyExpiry)
            }

        case .radius:
            FlowRow(spacing: 10) {
                ForEach(RadiusOption.all) { option in
                    Button {
                        radiusKm = option.km
                    } label: {
                        RFChip(title: "\(option.km) km",
                               selected: radiusKm == option.km,
                               caps: false)
                    }
                    .buttonStyle(.plain)
                }
            }

        case .verification:
            VerificationContent()

        case .blocked:
            BlockedInline()
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(RF.ui(15))
                .foregroundStyle(RF.Palette.ink)
        }
        .tint(RF.Palette.ink)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RF.Palette.line).frame(height: RF.Metric.hairline)
        }
    }
}

// MARK: - Verification

/// Documents never reach refind: the app hands off to a provider's hosted flow
/// and only ever sees a status back. That is the whole design decision here.
private struct VerificationContent: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL
    @State private var isStarting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Status").rfLabel(10)
                Spacer()
                Text(environment.verification.displayName)
                    .font(RF.ui(15, weight: .medium))
                    .foregroundStyle(environment.verification.isAttention
                                     ? RF.Palette.offer : RF.Palette.ink)
            }

            FinSays(state: .asking, mascotHeight: 64) {
                Text("Verifizierte Profile bekommen rund 40 % mehr Angebote.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            steps

            if environment.verification == .unverified || environment.verification == .rejected {
                Button(isStarting ? "Einen Moment …" : "Verifizierung starten") { start() }
                    .buttonStyle(RFButtonStyle(kind: isStarting ? .disabled : .primary))
                    .disabled(isStarting)
                    .accessibilityIdentifier("verification.start")
            }

            Text("Deine Ausweisdaten gehen direkt an unseren Prüfpartner. refind speichert sie nicht.")
                .rfLabel(9, tracking: 0.9)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("1", "Ausweis fotografieren")
            row("2", "Kurzes Selfie")
            row("3", "Antwort meist in wenigen Minuten")
        }
    }

    private func row(_ number: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(RF.num(11, weight: .medium))
                .foregroundStyle(RF.Palette.paper)
                .frame(width: 22, height: 22)
                .background(RF.Palette.ink, in: Circle())
            Text(text)
                .font(RF.ui(14))
                .foregroundStyle(RF.Palette.inkMid)
            Spacer(minLength: 0)
        }
    }

    private func start() {
        isStarting = true
        Task {
            if let url = try? await environment.repository.startVerification() {
                environment.verification = .pending
                openURL(url)
            }
            isStarting = false
        }
    }
}

private struct BlockedInline: View {
    var body: some View {
        BlockedUsersList()
    }
}
