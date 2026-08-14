//
//  WantCard.swift
//  refind
//
//  The card that establishes the language for the rest of the app: white,
//  square, one hairline, no shadow.
//

import SwiftUI

/// Presentation only — the caller wraps it in whatever makes it tappable, so a
/// NavigationLink does not end up nesting a Button inside a Button.
struct WantCard: View {
    let want: Want

    /// A live want shows the LIVE dot until it is nearly over, then swaps to a
    /// countdown — the mock draws an 11-day want as LIVE and a 2-day one as
    /// "2 TAGE". Three days is where this puts the line.
    private static let countdownThreshold: TimeInterval = 3 * 86_400

    private var showsCountdown: Bool {
        want.isLive && want.expiresAt.timeIntervalSinceNow <= Self.countdownThreshold
    }

    private var hasNewOffers: Bool { want.unreadOfferCount > 0 }

    /// With a new-offer footer the meta line carries the region; without one it
    /// carries the offer count instead, which is how the two drawn cards differ.
    private var metaLine: String {
        if !hasNewOffers, want.offerCount > 0 {
            return "bis \(want.budgetMax.formatted) · \(want.offerCountLine)"
        }
        return want.constraintLine
    }

    var body: some View {
        RFCard {
            VStack(alignment: .leading, spacing: hasNewOffers ? 12 : 10) {
                HStack {
                    Text(want.category.displayName).rfLabel(10)
                    Spacer()
                    status
                }
                Text(want.title)
                    .font(RF.display(26))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(metaLine)
                    .font(RF.num(12, weight: .medium))
                    .foregroundStyle(RF.Palette.inkMid)
                if hasNewOffers { footer }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        if want.isLive {
            if showsCountdown {
                Text(RF.remaining(until: want.expiresAt)).rfLabel(10)
            } else {
                RFLiveDot()
            }
        } else if want.status == .paused {
            Text("Pausiert").rfLabel(10)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            // The rule inside a card is paper, not line — a step lighter than the border.
            Rectangle()
                .fill(RF.Palette.paper)
                .frame(height: RF.Metric.hairline)
            HStack {
                Text(newOfferLine)
                    .font(RF.ui(14, weight: .medium))
                    .foregroundStyle(RF.Palette.offer)
                Spacer()
                RFOfferBadge(count: want.unreadOfferCount, size: RF.Metric.badgeLarge)
            }
        }
    }

    private var newOfferLine: String {
        want.unreadOfferCount == 1 ? "1 neues Angebot" : "\(want.unreadOfferCount) neue Angebote"
    }
}

// MARK: - Expired

/// The expired want reads as a note that has come down off the wall: card-alt,
/// dashed, with Fin in his empty pose.
struct ExpiredWantCard: View {
    let want: Want
    var onRepublish: () -> Void = {}

    var body: some View {
        Button(action: onRepublish) {
            RFCard(borderColor: RF.Palette.lineStrong,
                   background: RF.Palette.cardAlt,
                   dashed: true) {
                HStack(spacing: 14) {
                    FinMascot(state: .empty, height: 40)
                    Text("\(want.title) – abgelaufen. Nochmal aufhängen?")
                        .font(RF.ui(13))
                        .foregroundStyle(RF.Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(want.title) abgelaufen. Nochmal aufhängen?")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Cards") {
    ZStack {
        RF.Palette.paper.ignoresSafeArea()
        VStack(spacing: RF.Metric.cardGap) {
            WantCard(want: MockSeed.omegaWant)
            WantCard(want: MockSeed.usmWant)
            ExpiredWantCard(want: MockSeed.veloWant)
        }
        .padding(RF.Metric.screenMargin)
    }
}
