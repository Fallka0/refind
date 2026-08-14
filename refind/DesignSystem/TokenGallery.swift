//
//  TokenGallery.swift
//  refind
//
//  Step-1 proof sheet: every token, surface, control and mascot state on one
//  scroll, so the system can be judged before any screen is built on it.
//  Not shipped — nothing in the product links here.
//

import SwiftUI

struct TokenGallery: View {
    @State private var chipSelection: Category? = .uhren
    @State private var fieldText = ""

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 44) {
                    header
                    fontCheck
                    section("01  Farbe") { colors }
                    section("02  Typografie") { typography }
                    section("03  Flächen") { surfaces }
                    section("04  Buttons") { buttons }
                    section("05  Chips") { chips }
                    section("06  Marken & Eingabe") { marks }
                    section("07  Maskottchen") { mascots }
                    section("08  Fotos & Avatare") { photos }
                    section("09  Formate") { formats }
                }
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.top, RF.Metric.topInsetTabbed)
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("refind").font(RF.display(44)).foregroundStyle(RF.Palette.ink)
            Text("DESIGN SYSTEM · V1").rfLabel(11)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).rfLabel(11)
            content()
        }
    }

    /// The one thing worth checking before anything else: did the two families load?
    private var fontCheck: some View {
        let missing = FontLoader.missing
        return RFCard(borderColor: missing.isEmpty ? RF.Palette.line : RF.Palette.offer) {
            VStack(alignment: .leading, spacing: 8) {
                Text(missing.isEmpty ? "SCHRIFTEN GELADEN" : "SCHRIFTEN FEHLEN")
                    .rfLabel(10, color: missing.isEmpty ? RF.Palette.muted : RF.Palette.offer)
                Text(missing.isEmpty
                     ? "Instrument Serif · Archivo Regular / Medium / SemiBold"
                     : missing.joined(separator: ", "))
                    .font(RF.ui(14))
                    .foregroundStyle(RF.Palette.inkMid)
            }
        }
    }

    // MARK: Sections

    private var colors: some View {
        let swatches: [(String, String, Color, Bool)] = [
            ("Ink", "#1A1917", RF.Palette.ink, false),
            ("Paper", "#EDEBE7", RF.Palette.paper, true),
            ("Card", "#FFFFFF", RF.Palette.card, true),
            ("Offer", "#B5442A", RF.Palette.offer, false),
            ("Muted", "#8C877E", RF.Palette.muted, false),
            ("Line", "#DCD8D2", RF.Palette.line, false),
            ("Line strong", "#C9C4BC", RF.Palette.lineStrong, false),
            ("Card alt", "#F7F6F3", RF.Palette.cardAlt, true),
            ("Ink soft", "#3A3833", RF.Palette.inkSoft, false),
            ("Ink mid", "#5C5850", RF.Palette.inkMid, false)
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                         spacing: 16) {
            ForEach(swatches, id: \.0) { name, hex, color, needsBorder in
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(color)
                        .frame(height: 68)
                        .overlay {
                            if needsBorder {
                                Rectangle().strokeBorder(RF.Palette.line,
                                                         lineWidth: RF.Metric.hairline)
                            }
                        }
                    Text(name).font(RF.ui(13, weight: .medium))
                    Text(hex).rfLabel(10)
                }
            }
        }
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: 22) {
            typeRow("Was suchst du?", RF.display(40), "Instrument Serif · 40 · Display")
            typeRow("Omega Seamaster 166.062", RF.display(26), "Instrument Serif · 26 · Titel")
            typeRow("Vintage Omega Seamaster", RF.ui(22, weight: .medium), "Archivo Medium · 22")
            typeRow("Suche Originalzustand, gerne mit Papieren. Zustand vor Preis.",
                    RF.ui(15), "Archivo Regular · 15 · Fliesstext")
            VStack(alignment: .leading, spacing: 10) {
                Text("CHF 1'850 · 4 Angebote").rfLabel(12, color: RF.Palette.ink)
                Text("Archivo Medium · 12 · +12% · Tabellenziffern")
                    .font(RF.ui(11)).foregroundStyle(RF.Palette.muted)
            }
        }
    }

    private func typeRow(_ text: String, _ font: Font, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(font).foregroundStyle(RF.Palette.ink)
            Text(caption).font(RF.ui(11)).foregroundStyle(RF.Palette.muted)
            Rectangle().fill(RF.Palette.line).frame(height: RF.Metric.hairline)
        }
    }

    private var surfaces: some View {
        VStack(spacing: RF.Metric.cardGap) {
            RFCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("UHREN").rfLabel(10)
                        Spacer()
                        RFLiveDot()
                    }
                    Text("Omega Seamaster 166.062").font(RF.display(26))
                    Text("bis CHF 2'000 · Zürich").rfLabel(12, color: RF.Palette.inkMid)
                }
            }
            RFCard(borderColor: RF.Palette.ink) {
                Text("Betonte Karte · 1 pt ink").font(RF.ui(15, weight: .medium))
            }
            RFCard(background: RF.Palette.cardAlt,
                   dashed: true) {
                HStack(spacing: 14) {
                    FinMascot(state: .empty, height: 40)
                    Text("Rennvelo Gr. 56 – abgelaufen. Nochmal aufhängen?")
                        .font(RF.ui(13)).foregroundStyle(RF.Palette.muted)
                }
            }
            .environment(\.colorScheme, .light)
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button("Primär") {}.buttonStyle(RFButtonStyle(kind: .primary))
            Button("Sekundär") {}.buttonStyle(RFButtonStyle(kind: .secondary))
            Button("Angebot senden") {}.buttonStyle(RFButtonStyle(kind: .offerOutline))
            Button("Angebot bestätigen") {}.buttonStyle(RFButtonStyle(kind: .offerFilled))
            Button("Pausieren") {}.buttonStyle(RFButtonStyle(kind: .disabled))
        }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowRow(spacing: 10) {
                ForEach(Category.allCases) { category in
                    Button {
                        chipSelection = chipSelection == category ? nil : category
                    } label: {
                        RFChip(title: category.displayName, selected: chipSelection == category)
                    }
                    .buttonStyle(.plain)
                }
            }
            FlowRow(spacing: 8) {
                ForEach(Condition.allCases) { condition in
                    RFChip(title: condition.displayName,
                           selected: condition == .original,
                           caps: false)
                }
            }
        }
    }

    private var marks: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 26) {
                RFLiveDot()
                RFOfferBadge(count: 4)
                RFOfferBadge(count: 2, size: RF.Metric.badgeSmall)
                Text("2 TAGE").rfLabel(10)
            }
            RFUnderlineField(placeholder: "Was suchst du?", text: $fieldText)
        }
    }

    private var mascots: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 24) {
                mascot(.idle, "Idle")
                mascot(.asking, "Asking")
                mascot(.searching, "Searching")
            }
            HStack(spacing: 24) {
                mascot(.offerReceived, "Offer")
                mascot(.empty, "Empty")
                VStack(spacing: 10) {
                    FinMascot(state: .idle, height: 40)
                    Text("40 PT").rfLabel(9)
                }
            }
            FinSays {
                Text("Hoi, ich bin Fin. Hier zählt, was du suchst – nicht, was du loswerden willst.")
            }
        }
    }

    private func mascot(_ state: FinState, _ label: String) -> some View {
        VStack(spacing: 12) {
            FinMascot(state: state, height: 96)
            Text(label).rfLabel(9)
        }
        .frame(maxWidth: .infinity)
    }

    private var photos: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ForEach(["p-marc-1", "p-lena-1", "p-eames-1"], id: \.self) { seed in
                    RFMockPhoto(seed: seed)
                        .frame(width: RF.Metric.offerPhotoLarge,
                               height: RF.Metric.offerPhotoLarge)
                }
            }
            RFMockPhoto(seed: "p-werk", cornerRadius: RF.Metric.photoAttachmentRadius)
                .frame(width: RF.Metric.photoAttachmentWidth,
                       height: RF.Metric.photoAttachmentHeight)
            HStack(spacing: 14) {
                RFAvatar(initial: "r", style: .signet, size: RF.Metric.avatarHeader)
                RFAvatar(user: MockSeed.marc, size: RF.Metric.avatarChatRow)
                RFAvatar(user: MockSeed.nina, size: RF.Metric.avatarFeed)
            }
        }
    }

    private var formats: some View {
        VStack(alignment: .leading, spacing: 12) {
            formatRow("Preis", MockSeed.omegaWant.budgetMax.formatted)
            formatRow("Preis exakt", Money(chf: 1_650).formattedExact)
            formatRow("Treuhandgebühr", Escrow.fee(on: Money(chf: 1_650)).formattedExact)
            formatRow("Alter", RF.relativeAge(from: MockSeed.minutesAgo(12)))
            formatRow("Restlaufzeit", RF.remaining(until: MockSeed.usmWant.expiresAt))
            formatRow("Chat-Stempel", RF.chatStamp(MockSeed.minutesAgo(9)))
            formatRow("Übergabe", RF.handoverStamp(MockSeed.nextSaturdayAtTwo))
            formatRow("Beleg", RF.receiptStamp(.now))
            formatRow("Mitglied", RF.memberSince(MockSeed.me.memberSince))
        }
    }

    private func formatRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(RF.ui(14)).foregroundStyle(RF.Palette.inkMid)
            Spacer()
            Text(value).rfLabel(12, color: RF.Palette.ink)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(RF.Palette.line).frame(height: RF.Metric.hairline).offset(y: 8)
        }
    }
}

/// Wrapping row — chips and category grids need it in several places.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Tokens") {
    TokenGallery()
}
