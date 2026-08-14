//
//  OfferCard.swift
//  refind
//
//  Two weights of the same row: the leading offer gets a photo at 84 pt, the
//  message, an ink border and both actions; the rest are compact 60 pt rows.
//

import SwiftUI

struct LeadOfferCard: View {
    let offer: Offer
    let want: Want
    let onAccept: () -> Void
    let onChat: () -> Void

    var body: some View {
        // The emphasis is the border weight, not a fill or a shadow.
        RFCard(padding: 16, borderColor: RF.Palette.ink) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    OfferPhoto(offer: offer, size: RF.Metric.offerPhotoLarge)
                    VStack(alignment: .leading, spacing: 6) {
                        OfferHeadline(offer: offer)
                        Text(offer.trustLine(for: want)).rfLabel(10, tracking: 0.6)
                        if !offer.message.isEmpty {
                            Text(offer.message)
                                .font(RF.ui(13))
                                .foregroundStyle(RF.Palette.inkMid)
                                .lineLimit(2)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button("Annehmen", action: onAccept)
                        .buttonStyle(RFButtonStyle(kind: .primary))
                    Button("Chat", action: onChat)
                        .buttonStyle(RFButtonStyle(kind: .secondary))
                }
            }
        }
    }
}

struct CompactOfferCard: View {
    let offer: Offer
    let want: Want

    var body: some View {
        RFCard(padding: 16) {
            HStack(spacing: 14) {
                OfferPhoto(offer: offer, size: RF.Metric.offerPhotoCompact)
                VStack(alignment: .leading, spacing: 5) {
                    OfferHeadline(offer: offer)
                    Text(offer.trustLine(for: want)).rfLabel(10, tracking: 0.6)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pieces

private struct OfferHeadline: View {
    let offer: Offer

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(offer.seller.displayName)
                .font(RF.ui(15, weight: .medium))
                .foregroundStyle(RF.Palette.ink)
            Spacer(minLength: 8)
            Text(offer.price.formatted)
                .font(RF.num(14, weight: .medium))
                .foregroundStyle(RF.Palette.offer)
        }
    }
}

private struct OfferPhoto: View {
    let offer: Offer
    let size: CGFloat

    var body: some View {
        Group {
            if let photo = offer.photos.first {
                RFPhoto(photo: photo)
            } else {
                // No photo sent: an empty slot, not a broken image.
                Rectangle()
                    .fill(RF.Palette.cardAlt)
                    .overlay {
                        Rectangle().strokeBorder(RF.Palette.line,
                                                 lineWidth: RF.Metric.hairline)
                    }
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("Offers") {
    ZStack {
        RF.Palette.paper.ignoresSafeArea()
        VStack(spacing: 12) {
            LeadOfferCard(offer: MockSeed.offers[0], want: MockSeed.omegaWant,
                          onAccept: {}, onChat: {})
            CompactOfferCard(offer: MockSeed.offers[1], want: MockSeed.omegaWant)
            CompactOfferCard(offer: MockSeed.offers[3], want: MockSeed.omegaWant)
        }
        .padding(RF.Metric.screenMargin)
    }
}
