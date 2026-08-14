//
//  DealResultScreens.swift
//  refind
//
//  Screen 12 · Deal bestätigt (the cash-on-handover ending)
//  Screen 18 · Bezahlt · Treuhand aktiv (the escrow ending)
//

import SwiftUI

// MARK: - 12

struct DealConfirmedScreen: View {
    let store: DealStore
    let onDone: () -> Void
    @State private var showRating = false

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                FinMascot(state: .offerReceived, height: 124)

                Text("Gefunden.")
                    .font(RF.display(40))
                    .foregroundStyle(RF.Palette.ink)
                    .padding(.top, 50)

                Text("\(store.partnerFirstName) bringt \(store.thread.wantTitle) am Samstag nach Zürich. Details stehen im Chat.")
                    .font(RF.ui(15))
                    .foregroundStyle(RF.Palette.inkMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)
                    .padding(.top, 14)

                RFCard(borderColor: RF.Palette.ink) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Abschluss").rfLabel(10)
                            Spacer()
                            Text(store.amount.formatted)
                                .font(RF.num(15, weight: .medium))
                                .foregroundStyle(RF.Palette.offer)
                        }
                        Text(store.thread.wantTitle)
                            .font(RF.display(24))
                            .foregroundStyle(RF.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: 12) {
                            Rectangle().fill(RF.Palette.paper)
                                .frame(height: RF.Metric.hairline)
                            HStack {
                                Text(handoverLine).rfLabel(11, color: RF.Palette.inkMid)
                                Spacer()
                                Text(store.partnerName.uppercased())
                                    .rfLabel(11, color: RF.Palette.inkMid)
                            }
                        }
                    }
                }
                .padding(.top, 36)

                Spacer(minLength: 30)

                VStack(spacing: 12) {
                    Button("\(store.partnerFirstName) bewerten") { showRating = true }
                        .buttonStyle(RFButtonStyle(kind: .primary))
                        .accessibilityIdentifier("deal.rate")
                    Button("Fertig", action: onDone)
                        .buttonStyle(RFButtonStyle(kind: .secondary))
                        .accessibilityIdentifier("deal.done")
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 130)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
        .sheet(isPresented: $showRating) {
            RatingSheet(partnerName: store.partnerFirstName,
                        dealID: store.deal?.id ?? "")
        }
    }

    private var handoverLine: String {
        "\(RF.handoverStamp(store.deal?.handoverAt ?? MockSeed.nextSaturdayAtTwo)) · \((store.deal?.handoverPlace ?? "Zürich HB").uppercased())"
    }
}

// MARK: - 18

struct EscrowActiveScreen: View {
    let store: DealStore
    let onBackToChat: () -> Void
    @State private var showReceipt = false

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                FinMascot(state: .offerReceived, height: 105)

                Text("Geld ist sicher.")
                    .font(RF.display(38))
                    .foregroundStyle(RF.Palette.ink)
                    .padding(.top, 40)

                Text("\(store.partnerFirstName) sieht jetzt, dass bezahlt ist. Freigeben kannst du erst nach der Übergabe.")
                    .font(RF.ui(15))
                    .foregroundStyle(RF.Palette.inkMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)
                    .padding(.top, 12)

                RFCard(borderColor: RF.Palette.ink) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("In Treuhand").rfLabel(10)
                            Spacer()
                            Text(store.amount.formatted)
                                .font(RF.num(16, weight: .semibold))
                                .foregroundStyle(RF.Palette.offer)
                        }
                        tracker
                    }
                }
                .padding(.top, 32)

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    stageAction
                    Button("Zurück zum Chat", action: onBackToChat)
                        .buttonStyle(RFButtonStyle(kind: .secondary))
                        .accessibilityIdentifier("escrow.backToChat")
                    Button("Beleg ansehen") { showReceipt = true }
                        .buttonStyle(RFButtonStyle(kind: .secondary))
                    Text(footnote)
                        .font(RF.ui(13))
                        .foregroundStyle(RF.Palette.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 110)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
        .sheet(isPresented: $showReceipt) {
            if let escrow = store.escrow {
                ReceiptSheet(escrow: escrow,
                             partnerName: store.partnerName,
                             itemTitle: store.thread.wantTitle)
            }
        }
    }

    /// The screen's promise — "Nach der Übergabe erscheint hier «Geld
    /// freigeben»" — only holds if the stage can actually advance.
    @ViewBuilder
    private var stageAction: some View {
        switch store.escrow?.stage ?? .paid {
        case .paid:
            Button(store.isWorking ? "Einen Moment …" : "Übergabe bestätigen") {
                Task { await store.confirmHandover() }
            }
            .buttonStyle(RFButtonStyle(kind: store.isWorking ? .disabled : .primary))
            .disabled(store.isWorking)
            .accessibilityIdentifier("escrow.confirmHandover")
        case .handover:
            Button(store.isWorking ? "Einen Moment …" : "Geld freigeben") {
                Task { await store.release() }
            }
            .buttonStyle(RFButtonStyle(kind: store.isWorking ? .disabled : .offerFilled))
            .disabled(store.isWorking)
            .accessibilityIdentifier("escrow.release")
        case .released:
            EmptyView()
        }
    }

    private var footnote: String {
        switch store.escrow?.stage ?? .paid {
        case .paid:     return "Nach der Übergabe erscheint hier «Geld freigeben»."
        case .handover: return "Ohne Freigabe: Rückerstattung nach 72 Std."
        case .released: return "\(store.partnerFirstName) hat das Geld."
        }
    }

    private var tracker: some View {
        let stage = store.escrow?.stage ?? .paid
        return VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(Escrow.Stage.allCases, id: \.rawValue) { segment in
                    Rectangle()
                        .fill(segment.rawValue <= stage.rawValue
                              ? RF.Palette.ink : RF.Palette.line)
                        .frame(height: 3)
                }
            }
            HStack {
                ForEach(Escrow.Stage.allCases, id: \.rawValue) { segment in
                    Text(segment.displayName)
                        .rfLabel(9, tracking: 0.72,
                                 color: segment.rawValue <= stage.rawValue
                                        ? RF.Palette.ink : RF.Palette.muted)
                        .frame(maxWidth: .infinity,
                               alignment: alignment(for: segment))
                }
            }
            VStack(spacing: 12) {
                Rectangle().fill(RF.Palette.paper).frame(height: RF.Metric.hairline)
                HStack {
                    Text("Beleg \(store.escrow?.receiptNumber ?? MockSeed.receiptNumber)")
                        .font(RF.num(12, weight: .regular))
                        .foregroundStyle(RF.Palette.inkMid)
                    Spacer()
                    Text(RF.receiptStamp(store.escrow?.paidAt ?? .now))
                        .font(RF.num(12, weight: .regular))
                        .foregroundStyle(RF.Palette.inkMid)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Treuhand-Status: \(stage.displayName)")
    }

    private func alignment(for stage: Escrow.Stage) -> Alignment {
        switch stage {
        case .paid:     return .leading
        case .handover: return .center
        case .released: return .trailing
        }
    }
}
