//
//  ScrollableScreen.swift
//  refind
//
//  Several screens are designed as a fixed column with a Spacer pushing the
//  buttons to the bottom. That is right at normal type sizes and breaks at the
//  accessibility ones, where the content is taller than the screen: SwiftUI
//  centres the overflow, so the header slides under the status bar and the
//  primary button leaves the screen.
//
//  This keeps the Spacer behaviour while the content fits, and scrolls once it
//  does not.
//

import SwiftUI

struct ScrollableScreen: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            ScrollView {
                content
                    .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

extension View {
    /// Fixed column that survives the largest Dynamic Type sizes.
    func rfScrollableScreen() -> some View {
        modifier(ScrollableScreen())
    }
}

/// A saved card can be removed by long-pressing it. Plain ScrollViews have no
/// swipe-to-delete, and the design has no row chrome for one — a context menu
/// keeps the card exactly as drawn.
extension View {
    @ViewBuilder
    func swipeActionsCompatible(_ enabled: Bool,
                                action: @escaping () -> Void) -> some View {
        if enabled {
            contextMenu {
                Button("Aus Gespeichert entfernen", role: .destructive, action: action)
            }
        } else {
            self
        }
    }
}
