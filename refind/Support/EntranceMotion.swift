//
//  EntranceMotion.swift
//  refind
//
//  List and card entrances: spring, +10 pt from below, staggered 80 ms.
//  Under Reduce Motion the rise collapses to a cross-fade, per the handoff.
//

import SwiftUI

struct EntranceModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 10)
            .onAppear {
                let delay = Double(index) * RF.Motion.stagger
                withAnimation(
                    (reduceMotion ? .easeOut(duration: 0.25) : RF.Motion.entrance).delay(delay)
                ) {
                    shown = true
                }
            }
    }
}

extension View {
    /// Staggered entrance. `index` is the row's position in its list.
    func rfEntrance(_ index: Int = 0) -> some View {
        modifier(EntranceModifier(index: index))
    }
}
