//
//  HomeScreen.swift
//  refind
//
//  Screen 03 · Home · Meine Gesuche (tab 1)
//

import SwiftUI

struct HomeScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: HomeStore?
    @State private var isPostingWant = false

    /// Wired in step 5.
    var onSelectWant: (Want) -> Void = { _ in }

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            if let store {
                content(store)
            }
        }
        .task {
            let store = store ?? HomeStore(repository: environment.repository)
            self.store = store
            await store.load(store.segment)
        }
        .fullScreenCover(isPresented: $isPostingWant) {
            PostWantFlow { _ in
                // The new want lands at the top of Home.
                Task { await store?.load(.mine, force: true) }
            }
            .environment(environment)
        }
    }

    private func onPostWant() {
        isPostingWant = true
    }

    // MARK: Layout

    private func content(_ store: HomeStore) -> some View {
        @Bindable var store = store
        // Sticky button as a sibling, not a safeAreaInset: as an inset its
        // background does not composite above the scrolling cards.
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                SegmentedTextTabs(selection: $store.segment)
                list(store)
            }
            .padding(.top, RF.Metric.topInsetTabbed)
            postButton
        }
        .task(id: store.segment) { await store.load(store.segment) }
        .navigationDestination(for: Want.self) { want in
            WantDetailScreen(wantID: want.id)
                .environment(environment)
        }
    }

    private var header: some View {
        HStack {
            Text("refind")
                .font(RF.display(34))
                .foregroundStyle(RF.Palette.ink)
            Spacer()
            RFAvatar(initial: "r", style: .signet, size: RF.Metric.avatarHeader)
        }
        .padding(.horizontal, RF.Metric.screenMargin)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func list(_ store: HomeStore) -> some View {
        ScrollView {
            VStack(spacing: RF.Metric.cardGap) {
                switch store.current {
                case .idle, .loading:
                    ForEach(0..<3, id: \.self) { index in
                        RFSkeletonCard(showsFooter: index == 0)
                    }
                case .loaded(let wants) where wants.isEmpty:
                    RFEmptyState(message: emptyMessage,
                                 ctaTitle: emptyCTA,
                                 action: emptyAction(store))
                case .loaded(let wants):
                    ForEach(Array(wants.enumerated()), id: \.element.id) { index, want in
                        card(for: want, store: store)
                            .rfEntrance(index)
                    }
                case .failed(let message):
                    RFErrorState(message: message) {
                        Task { await store.load(store.segment, force: true) }
                    }
                }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 18)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func card(for want: Want, store: HomeStore) -> some View {
        if want.isExpired {
            ExpiredWantCard(want: want) {
                Task { await store.republish(want) }
            }
        } else {
            NavigationLink(value: want) {
                WantCard(want: want)
            }
            .buttonStyle(.plain)
            .swipeActionsCompatible(store.segment == .saved) {
                Task { await store.unsave(want) }
            }
        }
    }

    private var postButton: some View {
        Button(action: onPostWant) {
            HStack(spacing: 8) {
                Text("+")
                Text("Gesuch aufhängen")
            }
        }
        .buttonStyle(RFButtonStyle(kind: .primary))
        // The glyph is decoration; without this VoiceOver reads "plus, Gesuch
        // aufhängen".
        .accessibilityLabel("Gesuch aufhängen")
        .padding(.horizontal, RF.Metric.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(RF.Palette.paper.opacity(RF.Metric.barOpacity))
    }

    // MARK: Empty copy

    private var emptyMessage: String {
        store?.segment == .saved
            ? "Nichts gespeichert. Gesuche, die du dir merkst, landen hier."
            : "Noch kein Gesuch. Häng eines auf – andere melden sich bei dir."
    }

    private var emptyCTA: String {
        store?.segment == .saved ? "Zu Entdecken" : "Gesuch aufhängen"
    }

    private func emptyAction(_ store: HomeStore) -> () -> Void {
        store.segment == .saved ? {} : onPostWant
    }
}

#Preview("Home") {
    HomeScreen()
        .environment(AppEnvironment.preview)
}
