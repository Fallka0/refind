//
//  SplashScreen.swift
//  refind
//
//  Screen 01 · Splash. Ink full-bleed, Fin in paper, the wordmark wiped in
//  left to right over 1.1 s.
//

import SwiftUI

struct SplashScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            RF.Palette.ink.ignoresSafeArea()
            VStack(spacing: 40) {
                FinMascot(state: .idle, height: 114, monochrome: RF.Palette.paper)

                Text("refind")
                    .font(RF.display(62))
                    .foregroundStyle(RF.Palette.paper)
                    .mask(alignment: .leading) {
                        // The reveal is a wipe, not a fade: a mask that grows
                        // from the left edge.
                        GeometryReader { geo in
                            Rectangle()
                                .frame(width: revealed || reduceMotion ? geo.size.width : 0)
                        }
                    }
                    .opacity(reduceMotion && !revealed ? 0 : 1)

                Text("gesuche zuerst")
                    .rfLabel(10, tracking: 3, color: RF.Palette.muted)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : RF.Motion.logoReveal) {
                revealed = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("refind — gesuche zuerst")
    }
}

#Preview("01 Splash") {
    SplashScreen()
}
