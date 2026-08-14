//
//  RFSearchField.swift
//  refind
//
//  The pill search field — the one rounded input in the app, and only here.
//

import SwiftUI

struct RFSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .font(RF.ui(15))
                .tint(RF.Palette.offer)
                .foregroundStyle(RF.Palette.ink)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Text("×")
                        .font(RF.ui(17))
                        .foregroundStyle(RF.Palette.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(RF.Palette.card, in: Capsule())
        .overlay { Capsule().strokeBorder(RF.Palette.line, lineWidth: RF.Metric.hairline) }
    }
}

/// Brief confirmation after a send. Paper-on-ink, no icon, no colour.
struct RFToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(RF.ui(14, weight: .medium))
            .foregroundStyle(RF.Palette.paper)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(RF.Palette.ink, in: Capsule())
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
    }
}

extension View {
    /// Shows a toast above the bottom edge for a moment, then clears it.
    func rfToast(message: Binding<String?>) -> some View {
        overlay(alignment: .bottom) {
            if let text = message.wrappedValue {
                RFToast(message: text)
                    .padding(.bottom, 28)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(RF.Motion.entrance) { message.wrappedValue = nil }
                    }
            }
        }
        .animation(RF.Motion.entrance, value: message.wrappedValue)
    }
}
