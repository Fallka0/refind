//
//  RatingSheet.swift
//  refind
//
//  The rating prompt flow 4 ends on. Not drawn in the handoff, so it stays
//  deliberately plain: no stars — the brand shows ratings as figures ("4.9"),
//  so the input is figures too.
//

import SwiftUI

struct RatingSheet: View {
    let partnerName: String
    let dealID: String
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var stars = 0
    @State private var isSending = false

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Wie war der Deal mit \(partnerName)?")
                    .font(RF.display(32))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            stars = value
                        } label: {
                            Text("\(value)")
                                .font(RF.num(17, weight: .medium))
                                .foregroundStyle(value <= stars
                                                 ? RF.Palette.paper : RF.Palette.inkMid)
                                .frame(width: 52, height: 52)
                                .background(value <= stars ? RF.Palette.ink : RF.Palette.card,
                                            in: Circle())
                                .overlay {
                                    if value > stars {
                                        Circle().strokeBorder(RF.Palette.line, lineWidth: 1)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) von 5")
                        .accessibilityAddTraits(value == stars ? .isSelected : [])
                    }
                }
                .padding(.top, 28)

                Text("Deine Bewertung ist für alle sichtbar.")
                    .rfLabel(10)
                    .padding(.top, 16)

                Spacer(minLength: 30)

                VStack(spacing: 12) {
                    Button(isSending ? "Wird gesendet …" : "Bewertung senden") {
                        Task {
                            isSending = true
                            try? await environment.repository.rate(dealID: dealID, stars: stars)
                            isSending = false
                            dismiss()
                        }
                    }
                    .buttonStyle(RFButtonStyle(kind: stars > 0 && !isSending
                                               ? .primary : .disabled))
                    .disabled(stars == 0 || isSending)
                    .accessibilityIdentifier("rating.send")

                    Button("Später") { dismiss() }
                        .buttonStyle(RFButtonStyle(kind: .secondary))
                }
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
}

/// "Beleg ansehen" — the escrow receipt.
struct ReceiptSheet: View {
    let escrow: Escrow
    let partnerName: String
    let itemTitle: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Beleg")
                    .font(RF.display(32))
                    .foregroundStyle(RF.Palette.ink)
                Text(escrow.receiptNumber).rfLabel(11).padding(.top, 8)

                RFCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(itemTitle)
                            .font(RF.display(24))
                            .foregroundStyle(RF.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("von \(partnerName)")
                            .font(RF.ui(13))
                            .foregroundStyle(RF.Palette.muted)
                        VStack(spacing: 8) {
                            Rectangle().fill(RF.Palette.paper)
                                .frame(height: RF.Metric.hairline)
                            line("Preis", escrow.amount.formattedExact)
                            line(Escrow.feeRowLabel, escrow.fee.formattedExact)
                            Rectangle().fill(RF.Palette.paper)
                                .frame(height: RF.Metric.hairline)
                            line("Total", escrow.total.formattedExact, emphasised: true)
                            line("Bezahlt", RF.receiptStamp(escrow.paidAt))
                            line("Status", escrow.stage.displayName)
                        }
                    }
                }
                .padding(.top, 26)

                Text("Mock · kein echter Zahlungsbeleg")
                    .rfLabel(9, tracking: 0.9)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)

                Spacer(minLength: 24)

                Button("Schliessen") { dismiss() }
                    .buttonStyle(RFButtonStyle(kind: .secondary))
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 34)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
        .presentationCornerRadius(RF.Metric.sheetRadius)
        .presentationBackground(RF.Palette.paper)
    }

    private func line(_ label: String, _ value: String, emphasised: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasised ? RF.ui(15, weight: .semibold) : RF.ui(14))
                .foregroundStyle(emphasised ? RF.Palette.ink : RF.Palette.inkMid)
            Spacer()
            Text(value)
                .font(RF.num(emphasised ? 15 : 14, weight: emphasised ? .semibold : .regular))
                .foregroundStyle(emphasised ? RF.Palette.offer : RF.Palette.ink)
        }
    }
}
