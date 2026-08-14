//
//  RFStates.swift
//  refind
//
//  The three states every list owes besides content: skeleton, empty, error.
//  Shared so they cannot drift apart from screen to screen.
//

import SwiftUI

// MARK: - Loading

/// Skeleton cards, never a spinner. Blocks sit at the sizes of the real
/// content so the list does not jump when it arrives.
struct RFSkeletonCard: View {
    var lines: [CGFloat] = [64, 220, 140]
    var showsFooter: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        RFCard {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, width in
                    block(width: width, height: index == 1 ? 26 : 12)
                }
                if showsFooter {
                    Rectangle()
                        .fill(RF.Palette.paper)
                        .frame(height: RF.Metric.hairline)
                        .padding(.top, 2)
                    block(width: 120, height: 14)
                }
            }
        }
        .opacity(reduceMotion ? 0.7 : (pulse ? 0.45 : 0.8))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }

    private func block(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(RF.Palette.cardAlt)
            .frame(width: width, height: height)
    }
}

// MARK: - Empty

/// Fin plus one line of copy plus the relevant CTA. Never more than one line —
/// if it needs two, the copy is wrong.
struct RFEmptyState: View {
    let message: String
    var ctaTitle: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 22) {
            FinMascot(state: .empty, height: 92)
            Text(message)
                .font(RF.ui(14))
                .foregroundStyle(RF.Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            if let ctaTitle {
                Button(ctaTitle, action: action)
                    .buttonStyle(RFButtonStyle(kind: .secondary))
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

// MARK: - Error

/// Inline line plus "Nochmal versuchen" — never a full-screen takeover.
struct RFErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(message.uppercased()).rfLabel(11, color: RF.Palette.offer)
            Button("Nochmal versuchen", action: retry)
                .buttonStyle(RFButtonStyle(kind: .secondary))
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

#Preview("States") {
    ZStack {
        RF.Palette.paper.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 24) {
                RFSkeletonCard(showsFooter: true)
                RFEmptyState(message: "Noch kein Gesuch. Häng eines auf – andere melden sich bei dir.",
                             ctaTitle: "Gesuch aufhängen")
                RFErrorState(message: "Keine Verbindung.") {}
            }
            .padding(RF.Metric.screenMargin)
        }
    }
}
