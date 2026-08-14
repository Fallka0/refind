//
//  DiscoverWantCard.swift
//  refind
//
//  Someone else's want. Same card language as Home, but headed by the person
//  and footed by the offer action.
//

import SwiftUI

struct DiscoverWantCard: View {
    let want: Want
    let owner: User
    var isSaved: Bool = false
    let onSendOffer: () -> Void
    var onToggleSaved: () -> Void = {}

    var body: some View {
        RFCard {
            VStack(alignment: .leading, spacing: want.itemDescription == nil ? 10 : 12) {
                HStack {
                    HStack(spacing: 10) {
                        RFAvatar(user: owner, size: RF.Metric.avatarFeed)
                        Text(owner.displayName)
                            .font(RF.ui(14, weight: .medium))
                            .foregroundStyle(RF.Palette.ink)
                    }
                    Spacer()
                    Text(RF.relativeAge(from: want.createdAt)).rfLabel(10)
                    Button(action: onToggleSaved) {
                        // The note-shape again: saving a want is pinning the slip.
                        NoteShape()
                            .fill(isSaved ? RF.Palette.ink : .clear)
                            .overlay { NoteShape().stroke(isSaved ? RF.Palette.ink : RF.Palette.lineStrong, lineWidth: 1.5) }
                            .frame(width: 13, height: 16)
                            .frame(width: RF.Metric.minHitTarget, height: RF.Metric.minHitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? "Gespeichert" : "Speichern")
                    .accessibilityAddTraits(isSaved ? .isSelected : [])
                }

                Text(want.title)
                    .font(RF.display(26))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = want.itemDescription {
                    Text(description)
                        .font(RF.ui(13))
                        .foregroundStyle(RF.Palette.inkMid)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Rectangle()
                        .fill(RF.Palette.paper)
                        .frame(height: RF.Metric.hairline)
                    HStack {
                        Text("bis \(want.budgetMax.formatted)")
                            .font(RF.num(12, weight: .medium))
                            .foregroundStyle(RF.Palette.ink)
                        Spacer()
                        Button("Angebot senden", action: onSendOffer)
                            .buttonStyle(OfferPillStyle())
                    }
                }
            }
        }
    }
}

/// The compact offer-outline pill in a card footer — shorter than the 52 pt
/// full-width button, same colours.
private struct OfferPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RF.ui(13, weight: .medium))
            .foregroundStyle(RF.Palette.offer)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .frame(minHeight: RF.Metric.minHitTarget)
            .overlay { Capsule().strokeBorder(RF.Palette.offer, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("Discover card") {
    ZStack {
        RF.Palette.paper.ignoresSafeArea()
        VStack(spacing: 12) {
            DiscoverWantCard(want: MockSeed.eamesWant, owner: MockSeed.nina,
                             isSaved: true, onSendOffer: {})
            DiscoverWantCard(want: MockSeed.leicaWant, owner: MockSeed.samuel,
                             onSendOffer: {})
        }
        .padding(RF.Metric.screenMargin)
    }
}
