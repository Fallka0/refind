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
    case payment, notifications, radius, verification
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
            VStack(alignment: .leading, spacing: 18) {
                FinSays(state: .asking, mascotHeight: 64) {
                    Text("Verifizierte Profile bekommen rund 40 % mehr Angebote.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Der Ablauf steht noch nicht. Sobald er da ist, findest du ihn hier.")
                    .font(RF.ui(14))
                    .foregroundStyle(RF.Palette.inkMid)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
