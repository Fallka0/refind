//
//  ChatsScreen.swift
//  refind
//
//  Screen 10 · Chats (tab 3)
//

import SwiftUI

@MainActor
@Observable
final class ChatsStore {
    var threads: LoadState<[ChatThread]> = .idle
    private let repository: any RefindRepository

    init(repository: any RefindRepository) { self.repository = repository }

    func load() async {
        if threads.value == nil { threads = .loading }
        do {
            threads = .loaded(try await repository.threads())
        } catch {
            threads = .failed((error as? RepositoryError)?.inlineMessage
                              ?? RepositoryError.server.inlineMessage)
        }
    }
}

struct ChatsScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: ChatsStore?

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            if let store { content(store) }
        }
        .task {
            let store = store ?? ChatsStore(repository: environment.repository)
            self.store = store
            await store.load()
        }
        .navigationDestination(for: ChatThread.self) { thread in
            ChatScreen(thread: thread)
                .environment(environment)
        }
    }

    private func content(_ store: ChatsStore) -> some View {
        VStack(spacing: 0) {
            Text("Chats")
                .font(RF.display(34))
                .foregroundStyle(RF.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                LazyVStack(spacing: 0) {
                    switch store.threads {
                    case .idle, .loading:
                        ForEach(0..<3, id: \.self) { _ in
                            RFSkeletonCard(lines: [120, 200, 90])
                                .padding(.horizontal, RF.Metric.screenMargin)
                                .padding(.bottom, 12)
                        }
                    case .loaded(let threads) where threads.isEmpty:
                        RFEmptyState(message: "Noch keine Chats. Sie entstehen, sobald ein Angebot kommt.",
                                     ctaTitle: nil)
                    case .loaded(let threads):
                        ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                            NavigationLink(value: thread) {
                                ChatRow(thread: thread)
                            }
                            .buttonStyle(.plain)
                            .rfEntrance(index)
                        }
                        // Closes the last row's rule.
                        Rectangle()
                            .fill(RF.Palette.line)
                            .frame(height: RF.Metric.hairline)
                        archiveNote
                    case .failed(let message):
                        RFErrorState(message: message) { Task { await store.load() } }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.load() }
        }
        .padding(.top, RF.Metric.topInsetTabbed)
    }

    /// The one Fin allowed on this screen.
    private var archiveNote: some View {
        VStack(spacing: 16) {
            FinMascot(state: .empty, height: 52)
            Text("Ältere Chats werden nach 60 Tagen archiviert.")
                .font(RF.ui(13))
                .foregroundStyle(RF.Palette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct ChatRow: View {
    let thread: ChatThread

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(RF.Palette.line)
                .frame(height: RF.Metric.hairline)
            HStack(spacing: 14) {
                RFAvatar(user: thread.partner, size: RF.Metric.avatarChatRow)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(thread.partner.displayName)
                            .font(RF.ui(15, weight: thread.isUnread ? .semibold : .medium))
                            .foregroundStyle(RF.Palette.ink)
                        Spacer(minLength: 8)
                        Text(RF.chatStamp(thread.lastActivity)).rfLabel(10)
                    }
                    Text(thread.lastMessagePreview)
                        .font(RF.ui(13))
                        .foregroundStyle(thread.isUnread ? RF.Palette.inkSoft : RF.Palette.muted)
                        .lineLimit(1)
                    Text(thread.contextLine).rfLabel(10, tracking: 0.6)
                }
                if thread.isUnread {
                    Text("\(thread.unreadCount)")
                        .font(RF.num(10))
                        .foregroundStyle(.white)
                        .frame(width: RF.Metric.badgeSmall, height: RF.Metric.badgeSmall)
                        .background(RF.Palette.offer, in: Circle())
                }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.vertical, 16)
            // Unread rows sit on card, read rows on paper.
            .background(thread.isUnread ? RF.Palette.card : Color.clear)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("10 Chats") {
    NavigationStack {
        ChatsScreen().environment(AppEnvironment.preview)
    }
}
