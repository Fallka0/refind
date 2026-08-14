//
//  PaymentSteps.swift
//  refind
//
//  Screens 14 · 15 · 16 · 17 — the mock escrow flow.
//  Every screen carries its own "Mock" line, exactly as the designs do.
//

import SwiftUI

// MARK: - 14 · Zahlung wählen

struct PaymentMethodStep: View {
    @Bindable var store: DealStore
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var showExplainer = false

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        RFFlowHeader(leadingTitle: "Zurück", step: 1, onLeading: onBack)

                        Text("Wie bezahlst du \(store.partnerFirstName)?")
                            .font(RF.display(40))
                            .foregroundStyle(RF.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 26)

                        Text("\(store.thread.wantTitle) · \(store.amount.formatted)")
                            .font(RF.ui(14))
                            .foregroundStyle(RF.Palette.inkMid)
                            .padding(.top, 10)

                        VStack(spacing: 12) {
                            ForEach(PaymentMethod.allCases) { method in
                                option(method)
                            }
                        }
                        .padding(.top, 30)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, RF.Metric.screenMargin)
                    .padding(.top, RF.Metric.topInsetFlow)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 10) {
                    Button("Weiter", action: onNext)
                        .buttonStyle(RFButtonStyle(kind: .primary))
                        .accessibilityIdentifier("pay.next")
                    Text("Mock · keine echte Zahlung").rfLabel(9, tracking: 0.9)
                }
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showExplainer) {
            EscrowExplainerSheet(store: store)
        }
    }

    @ViewBuilder
    private func option(_ method: PaymentMethod) -> some View {
        let selected = store.method == method
        Button {
            store.method = method
        } label: {
            RFCard(borderColor: selected ? RF.Palette.ink : RF.Palette.line) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Radio(selected: selected)
                        Text(method.displayName)
                            .font(RF.ui(16, weight: selected ? .semibold : .medium))
                            .foregroundStyle(RF.Palette.ink)
                        Spacer()
                        if method.isRecommended {
                            Text("Empfohlen")
                                .rfLabel(9, tracking: 0.9, color: RF.Palette.offer)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .overlay {
                                    Rectangle().strokeBorder(RF.Palette.offer, lineWidth: 1)
                                }
                        }
                    }
                    if selected {
                        Text(method.explanation)
                            .font(RF.ui(13))
                            .foregroundStyle(RF.Palette.inkMid)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if method == .escrow {
                            VStack(spacing: 10) {
                                Rectangle().fill(RF.Palette.paper)
                                    .frame(height: RF.Metric.hairline)
                                HStack {
                                    Button("Gebühr 2.5 %") { showExplainer = true }
                                        .font(RF.num(12, weight: .medium))
                                        .foregroundStyle(RF.Palette.inkMid)
                                        .buttonStyle(.plain)
                                    Spacer()
                                    Text(store.fee.formattedExact)
                                        .font(RF.num(12, weight: .medium))
                                        .foregroundStyle(RF.Palette.ink)
                                }
                            }
                        }
                    } else {
                        Text(method.explanation)
                            .font(RF.ui(13))
                            .foregroundStyle(RF.Palette.muted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct Radio: View {
    let selected: Bool

    var body: some View {
        Circle()
            .strokeBorder(selected ? RF.Palette.ink : RF.Palette.lineStrong,
                          lineWidth: selected ? 5 : 1.5)
            .frame(width: 18, height: 18)
    }
}

// MARK: - 15 · Treuhand erklärt

struct EscrowExplainerSheet: View {
    let store: DealStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Button("Schliessen") { dismiss() }
                    .font(RF.ui(15))
                    .foregroundStyle(RF.Palette.muted)
                    .frame(minHeight: RF.Metric.minHitTarget, alignment: .leading)

                FinSays(state: .asking, mascotHeight: 69) {
                    Text("Niemand muss dem anderen vertrauen – das übernehmen wir kurz.")
                }
                .padding(.top, 30)

                Text("So funktioniert die Treuhand")
                    .font(RF.display(38))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 36)

                VStack(spacing: 0) {
                    step(1, "Du bezahlst an refind",
                         "Das Geld liegt bei uns, nicht bei \(store.partnerFirstName).",
                         isLast: false)
                    step(2, "Übergabe",
                         "\(RF.handoverStamp(MockSeed.nextSaturdayAtTwo).capitalized), Zürich HB. Du prüfst in Ruhe.",
                         isLast: false)
                    step(3, "Du gibst frei",
                         "Ein Tipp im Chat, \(store.partnerFirstName) hat das Geld. Ohne Freigabe: Rückerstattung nach 72 Std.",
                         isLast: true)
                }
                .padding(.top, 30)

                Spacer(minLength: 20)

                Button("Verstanden") { dismiss() }
                    .buttonStyle(RFButtonStyle(kind: .primary))
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, RF.Metric.topInsetFlow)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
        .presentationCornerRadius(RF.Metric.sheetRadius)
        .presentationBackground(RF.Palette.paper)
    }

    private func step(_ number: Int, _ title: String, _ body: String,
                      isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(RF.num(12, weight: .medium))
                    .foregroundStyle(isLast ? .white : RF.Palette.paper)
                    .frame(width: 26, height: 26)
                    .background(isLast ? RF.Palette.offer : RF.Palette.ink, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(RF.Palette.line)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RF.ui(16, weight: .semibold))
                    .foregroundStyle(RF.Palette.ink)
                Text(body)
                    .font(RF.ui(13))
                    .foregroundStyle(RF.Palette.inkMid)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 26)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 16 · Zahlungsmittel

struct CardStep: View {
    @Bindable var store: DealStore
    let onBack: () -> Void
    let onNext: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        RFFlowHeader(leadingTitle: "Zurück", step: 2, onLeading: onBack)

                        Text("Zahlungsmittel")
                            .font(RF.display(40))
                            .foregroundStyle(RF.Palette.ink)
                            .padding(.top, 26)

                        Button {
                            store.cardNumber = "4242 4242 4242 4242"
                            onNext()
                        } label: {
                            Text("\u{F8FF}  Pay")
                        }
                        .buttonStyle(RFButtonStyle(kind: .primary))
                        .padding(.top, 22)
                        .accessibilityLabel("Mit Apple Pay bezahlen")

                        HStack(spacing: 12) {
                            Rectangle().fill(RF.Palette.line).frame(height: 1)
                            Text("oder Karte").rfLabel(9, tracking: 1.08)
                            Rectangle().fill(RF.Palette.line).frame(height: 1)
                        }
                        .padding(.vertical, 20)

                        VStack(alignment: .leading, spacing: 20) {
                            field(title: "Kartennummer",
                                  text: $store.cardNumber,
                                  placeholder: "4242 4242 4242 4242",
                                  emphasised: true)
                            HStack(spacing: 20) {
                                field(title: "Gültig bis", text: $store.expiry,
                                      placeholder: "MM / JJ", emphasised: false)
                                field(title: "CVC", text: $store.cvc,
                                      placeholder: "···", emphasised: false)
                            }
                        }

                        Toggle(isOn: $store.saveCard) {
                            Text("Karte für nächste Deals speichern")
                                .font(RF.ui(13))
                                .foregroundStyle(RF.Palette.inkMid)
                        }
                        .toggleStyle(SquareToggleStyle())
                        .padding(.top, 22)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, RF.Metric.screenMargin)
                    .padding(.top, RF.Metric.topInsetFlow)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 10) {
                    Button("Weiter", action: onNext)
                        .buttonStyle(RFButtonStyle(kind: store.cardIsValid ? .primary : .disabled))
                        .disabled(!store.cardIsValid)
                        .accessibilityIdentifier("card.next")
                    Text("Mock · keine echte Zahlung").rfLabel(9, tracking: 0.9)
                }
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.bottom, 16)
            }
        }
    }

    private func field(title: String, text: Binding<String>,
                       placeholder: String, emphasised: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).rfLabel(10)
            TextField(placeholder, text: text)
                .font(RF.num(19, weight: .regular))
                .foregroundStyle(RF.Palette.ink)
                .tint(RF.Palette.offer)
                .keyboardType(.numbersAndPunctuation)
                .padding(.bottom, 9)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(emphasised ? RF.Palette.ink : RF.Palette.line)
                        .frame(height: emphasised ? RF.Metric.inputRule : RF.Metric.hairline)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Square checkbox — the brand has no rounded controls except capsules.
private struct SquareToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle()
                        .strokeBorder(RF.Palette.ink, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if configuration.isOn {
                        Text("✓")
                            .font(RF.ui(12, weight: .medium))
                            .foregroundStyle(RF.Palette.ink)
                    }
                }
                configuration.label
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - 17 · Bestätigen · Face ID

struct ConfirmPayStep: View {
    @Bindable var store: DealStore
    let onBack: () -> Void
    let onPaid: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RF.Palette.paper.ignoresSafeArea()

            // The summary dims behind the authorisation sheet, as drawn.
            VStack(alignment: .leading, spacing: 0) {
                RFFlowHeader(leadingTitle: "Zurück", step: 3, onLeading: onBack)
                Text("Prüfen und bezahlen")
                    .font(RF.display(40))
                    .foregroundStyle(RF.Palette.ink)
                    .padding(.top, 26)
                summaryCard.padding(.top, 26)
                Spacer()
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, RF.Metric.topInsetFlow)
            .opacity(0.45)

            authorisationSheet
        }
    }

    private var summaryCard: some View {
        RFCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.thread.wantTitle)
                    .font(RF.display(24))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("von \(store.partnerName) · Übergabe \(RF.handoverStamp(MockSeed.nextSaturdayAtTwo).capitalized)")
                    .font(RF.ui(13))
                    .foregroundStyle(RF.Palette.muted)
                VStack(spacing: 8) {
                    Rectangle().fill(RF.Palette.paper).frame(height: RF.Metric.hairline)
                    row("Preis", store.amount.formattedExact, emphasised: false)
                    row(Escrow.feeRowLabel, store.fee.formattedExact, emphasised: false)
                    Rectangle().fill(RF.Palette.paper).frame(height: RF.Metric.hairline)
                    row("Total", store.total.formattedExact, emphasised: true)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String, emphasised: Bool) -> some View {
        HStack {
            Text(label)
                .font(emphasised ? RF.ui(16, weight: .semibold) : RF.ui(14))
                .foregroundStyle(emphasised ? RF.Palette.ink : RF.Palette.inkMid)
            Spacer()
            Text(value)
                .font(RF.num(emphasised ? 16 : 14, weight: emphasised ? .semibold : .regular))
                .foregroundStyle(emphasised ? RF.Palette.offer : RF.Palette.ink)
        }
    }

    private var authorisationSheet: some View {
        VStack(spacing: 18) {
            FaceIDGlyph()
            Text("Mit Face ID bezahlen")
                .font(RF.display(26))
                .foregroundStyle(RF.Palette.ink)
            Text("\(store.total.formattedExact) an refind Treuhand")
                .font(RF.num(14, weight: .regular))
                .foregroundStyle(RF.Palette.inkMid)
            Button(store.isWorking ? "Wird bestätigt …" : "Bestätigen") {
                Task { if await store.authorise() { onPaid() } }
            }
            .buttonStyle(RFButtonStyle(kind: store.isWorking ? .disabled : .primary))
            .disabled(store.isWorking)
            .accessibilityIdentifier("pay.confirm")
            Text("Mock · kein echter Zahlungsvorgang").rfLabel(9, tracking: 0.9)
        }
        .padding(.horizontal, RF.Metric.screenMargin)
        .padding(.top, 26)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: RF.Metric.sheetRadius,
                                   topTrailingRadius: RF.Metric.sheetRadius)
                .fill(RF.Palette.card)
                .ignoresSafeArea(edges: .bottom)
        }
        .transition(.move(edge: .bottom))
    }
}

/// Face ID mark, drawn from primitives like every other glyph.
private struct FaceIDGlyph: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(RF.Palette.ink, lineWidth: 2.5)
            .frame(width: 56, height: 56)
            .overlay {
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        Capsule().fill(RF.Palette.ink).frame(width: 5, height: 12)
                        Capsule().fill(RF.Palette.ink).frame(width: 5, height: 12)
                    }
                    Smile2().stroke(RF.Palette.ink, lineWidth: 2.5)
                        .frame(width: 22, height: 7)
                }
                .offset(y: 2)
            }
            .accessibilityHidden(true)
    }
}

private struct Smile2: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 2))
        return p
    }
}
