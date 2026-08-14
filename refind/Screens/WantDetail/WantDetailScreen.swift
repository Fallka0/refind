//
//  WantDetailScreen.swift
//  refind
//
//  Screen 07 · Gesuch-Detail · Angebote
//

import SwiftUI

struct WantDetailScreen: View {
    let wantID: String
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var store: WantDetailStore?
    @State private var isEditing = false

    /// Wired in step 7.
    var onOpenThread: (ChatThread) -> Void = { _ in }

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            if let store {
                content(store)
            }
        }
        .navigationBarBackButtonHidden()
        .task {
            let store = store ?? WantDetailStore(wantID: wantID,
                                                 repository: environment.repository)
            self.store = store
            await store.load()
        }
    }

    @ViewBuilder
    private func content(_ store: WantDetailStore) -> some View {
        // The bar is a sibling, not a safeAreaInset — as an inset its background
        // would not composite above the scrolling offers. The mock stacks them
        // this way too: the list ends where the bar begins.
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header(store)
                if let want = store.want.value {
                    titleBlock(want)
                    sectionRow(store)
                    offerList(store, want: want)
                } else if let message = store.want.errorMessage {
                    RFErrorState(message: message) { Task { await store.load(force: true) } }
                    Spacer()
                } else {
                    Spacer()
                }
            }
            .padding(.top, RF.Metric.topInsetTabbed)
            bottomBar(store)
        }
        .alert("Angebot annehmen?",
               isPresented: Binding(get: { store.pendingAccept != nil },
                                    set: { if !$0 { store.pendingAccept = nil } })) {
            Button("Abbrechen", role: .cancel) { store.pendingAccept = nil }
            Button("Annehmen") { Task { await store.confirmAccept() } }
        } message: {
            Text("Die anderen Anbieter werden informiert.")
        }
        .onChange(of: store.acceptedThread) { _, thread in
            if let thread { onOpenThread(thread) }
        }
        .sheet(isPresented: $isEditing) {
            if let want = store.want.value {
                EditWantSheet(want: want) { _ in
                    Task { await store.load(force: true) }
                }
                .environment(environment)
            }
        }
    }

    private func header(_ store: WantDetailStore) -> some View {
        HStack {
            Button("Zurück") { dismiss() }
                .font(RF.ui(15))
                .foregroundStyle(RF.Palette.muted)
                .frame(minHeight: RF.Metric.minHitTarget, alignment: .leading)
            Spacer()
            if store.want.value?.isLive == true {
                RFLiveDot()
            } else if store.isPaused {
                Text("Pausiert").rfLabel(10)
            }
        }
        .padding(.horizontal, RF.Metric.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RF.Palette.line).frame(height: RF.Metric.hairline)
        }
    }

    private func titleBlock(_ want: Want) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(want.title)
                .font(RF.display(32))
                .foregroundStyle(RF.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(want.detailConstraintLine)
                .font(RF.num(12, weight: .medium))
                .foregroundStyle(RF.Palette.inkMid)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RF.Metric.screenMargin)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RF.Palette.line).frame(height: RF.Metric.hairline)
        }
    }

    private func sectionRow(_ store: WantDetailStore) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(offerCountTitle(store)).rfLabel(11, color: RF.Palette.ink)
            Spacer()
            Button {
                Task { await store.cycleSort() }
            } label: {
                // Sentence case, unlike the section title beside it — the mock
                // uppercases "4 ANGEBOTE" but leaves "Preis ↑" as written.
                Text(store.sort.displayName)
                    .font(RF.num(11, weight: .medium))
                    .foregroundStyle(RF.Palette.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sortierung: \(store.sort.displayName)")
        }
        .padding(.horizontal, RF.Metric.screenMargin)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func offerCountTitle(_ store: WantDetailStore) -> String {
        let count = store.offers.value?.count ?? store.want.value?.offerCount ?? 0
        return count == 1 ? "1 Angebot" : "\(count) Angebote"
    }

    @ViewBuilder
    private func offerList(_ store: WantDetailStore, want: Want) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                switch store.offers {
                case .idle, .loading:
                    ForEach(0..<3, id: \.self) { _ in RFSkeletonCard(lines: [90, 140]) }
                case .loaded(let offers) where offers.isEmpty:
                    RFEmptyState(message: "Noch keine Angebote. Wir sagen dir Bescheid, sobald eines kommt.",
                                 ctaTitle: nil)
                case .loaded(let offers):
                    ForEach(Array(offers.enumerated()), id: \.element.id) { index, offer in
                        row(offer, index: index, store: store, want: want)
                            .rfEntrance(index)
                    }
                case .failed(let message):
                    RFErrorState(message: message) { Task { await store.loadOffers() } }
                }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func row(_ offer: Offer, index: Int, store: WantDetailStore, want: Want) -> some View {
        if index == 0 {
            LeadOfferCard(
                offer: offer,
                want: want,
                onAccept: { store.pendingAccept = offer },
                onChat: { Task { await openThread(for: offer, store: store) } }
            )
        } else {
            CompactOfferCard(offer: offer, want: want)
        }
    }

    private func openThread(for offer: Offer, store: WantDetailStore) async {
        let threads = try? await environment.repository.threads()
        if let existing = threads?.first(where: { $0.offerID == offer.id }) {
            onOpenThread(existing)
        }
    }

    private func bottomBar(_ store: WantDetailStore) -> some View {
        // Same shape as RFTabBar: rule on top, content below, one background
        // across the whole stack. Backing only the content let the list show
        // through the bar.
        VStack(spacing: 0) {
            Rectangle()
                .fill(RF.Palette.line)
                .frame(height: RF.Metric.hairline)
            HStack(spacing: 10) {
                Button("Bearbeiten") { isEditing = true }
                    .buttonStyle(RFButtonStyle(kind: .secondary))
                    .accessibilityIdentifier("detail.edit")
                Button(store.isPaused ? "Fortsetzen" : "Pausieren") {
                    Task { await store.togglePaused() }
                }
                .buttonStyle(RFButtonStyle(kind: .disabled))
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.vertical, 14)
        }
        // No ignoresSafeArea here: expanding the layer out of the inset's
        // bounds left the list visible through the bar. The screen's own paper
        // already covers the home-indicator strip below.
        .background(RF.Palette.paper.opacity(RF.Metric.barOpacity))
    }
}

#Preview("07 Detail") {
    NavigationStack {
        WantDetailScreen(wantID: MockSeed.omegaWant.id)
            .environment(AppEnvironment.preview)
    }
}
