//
//  RFTabBar.swift
//  refind
//
//  The four tab glyphs are primitives, like everything else in the brand:
//  the want-note, a circle, a speech bubble with one squared tail corner, and
//  a filled dot. No SF Symbols — they would read as a different product.
//

import SwiftUI

struct RFTabBar: View {
    @Binding var selection: AppTab
    /// Total unread messages — the red dot on the chat glyph.
    var chatUnread: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(RF.Palette.line)
                .frame(height: RF.Metric.hairline)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    item(tab)
                }
            }
            .padding(.horizontal, RF.Metric.tabBarMargin)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background {
            RF.Palette.paper
                .opacity(RF.Metric.barOpacity)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = tab == selection
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 5) {
                glyph(tab, active: isSelected)
                    .frame(height: 18)
                Text(tab.title)
                    .rfLabel(9, tracking: 9 * 0.06,
                             color: isSelected ? RF.Palette.ink : RF.Palette.muted)
            }
            .frame(maxWidth: .infinity, minHeight: RF.Metric.minHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityValue(tab == .chat && chatUnread > 0
                            ? "\(chatUnread) ungelesene Nachrichten" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func glyph(_ tab: AppTab, active: Bool) -> some View {
        let tint = active ? RF.Palette.ink : RF.Palette.muted
        switch tab {
        case .gesuche:
            NoteShape()
                .fill(tint)
                .frame(width: 15, height: 18)
        case .entdecken:
            Circle()
                .strokeBorder(tint, lineWidth: 2)
                .frame(width: 16, height: 16)
        case .chat:
            ChatGlyph()
                .strokeBorder(tint, lineWidth: 2)
                .frame(width: 17, height: 15)
                .overlay(alignment: .topTrailing) {
                    if chatUnread > 0 {
                        Circle()
                            .fill(RF.Palette.offer)
                            .frame(width: 8, height: 8)
                            .offset(x: 5, y: -5)
                    }
                }
        case .profil:
            Circle()
                .fill(active ? RF.Palette.ink : RF.Palette.lineStrong)
                .frame(width: 16, height: 16)
        }
    }
}

/// Speech bubble: rounded except the bottom-left, which squares off into the tail.
private struct ChatGlyph: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        return UnevenRoundedRectangle(
            topLeadingRadius: 5,
            bottomLeadingRadius: 1,
            bottomTrailingRadius: 5,
            topTrailingRadius: 5
        ).path(in: r)
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

#Preview("Tab bar") {
    @Previewable @State var selection: AppTab = .gesuche
    return ZStack(alignment: .bottom) {
        RF.Palette.paper.ignoresSafeArea()
        RFTabBar(selection: $selection, chatUnread: 2)
    }
}
