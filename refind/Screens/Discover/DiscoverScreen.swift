//
//  DiscoverScreen.swift
//  refind
//
//  Screen 08 · Entdecken · Gesuche anderer (tab 2)
//

import SwiftUI

struct DiscoverScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: DiscoverStore?

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            if let store {
                content(store)
            }
        }
        .task {
            let store = store ?? DiscoverStore(repository: environment.repository)
            self.store = store
            if store.wants.value == nil { await store.load() }
            await store.refreshSaved()
        }
    }

    private func content(_ store: DiscoverStore) -> some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Entdecken")
                    .font(RF.display(34))
                    .foregroundStyle(RF.Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                RFSearchField(placeholder: "Wer sucht was?", text: $store.query)
                    .onChange(of: store.query) { _, _ in store.queryChanged() }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 12)
            .padding(.bottom, 14)

            categoryRow(store)
            list(store)
        }
        .padding(.top, RF.Metric.topInsetTabbed)
        .sheet(item: $store.offerTarget) { want in
            SendOfferSheet(want: want, recipient: store.owner(of: want)) {
                store.toast = "Angebot gesendet"
            }
            .environment(environment)
        }
        .rfToast(message: $store.toast)
    }

    private func categoryRow(_ store: DiscoverStore) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: "Alle", selected: store.category == nil) {
                    Task { await store.select(nil) }
                }
                ForEach(Category.allCases) { category in
                    chip(title: category.displayName, selected: store.category == category) {
                        Task { await store.select(store.category == category ? nil : category) }
                    }
                }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 14)
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RFChip(title: title, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func list(_ store: DiscoverStore) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                switch store.wants {
                case .idle, .loading:
                    ForEach(0..<3, id: \.self) { _ in RFSkeletonCard(showsFooter: true) }
                case .loaded(let wants) where wants.isEmpty:
                    RFEmptyState(message: emptyMessage(store), ctaTitle: nil)
                case .loaded(let wants):
                    ForEach(Array(wants.enumerated()), id: \.element.id) { index, want in
                        DiscoverWantCard(
                            want: want,
                            owner: store.owner(of: want),
                            isSaved: store.savedIDs.contains(want.id),
                            onSendOffer: { store.offerTarget = want },
                            onToggleSaved: { Task { await store.toggleSaved(want) } }
                        )
                        .rfEntrance(index)
                    }
                case .failed(let message):
                    RFErrorState(message: message) { Task { await store.load() } }
                }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
    }

    private func emptyMessage(_ store: DiscoverStore) -> String {
        store.query.isEmpty && store.category == nil
            ? "Hier ist gerade nichts. Schau später nochmal vorbei."
            : "Nichts gefunden. Versuch einen anderen Begriff."
    }
}

#Preview("08 Entdecken") {
    DiscoverScreen()
        .environment(AppEnvironment.preview)
}
