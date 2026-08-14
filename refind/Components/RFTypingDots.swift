//
//  RFTypingDots.swift
//  refind
//
//  Three 6 pt dots, translateY −4 pt, 1.2 s, staggered 150 ms.
//

import SwiftUI

struct RFTypingDots: View {
    var color: Color = RF.Palette.muted

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion ? 0.6 : (animating ? 1 : 0.25))
                    .offset(y: reduceMotion ? 0 : (animating ? -4 : 0))
                    .animation(
                        reduceMotion ? nil
                        : .easeInOut(duration: RF.Motion.typingDots / 2)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("Schreibt gerade")
    }
}
