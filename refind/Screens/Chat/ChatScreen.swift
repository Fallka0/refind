//
//  ChatScreen.swift
//  refind
//
//  Screen 11 · Chat · Verhandlung. No mascot here — only humans speak in a
//  negotiation.
//

import SwiftUI
import PhotosUI

@MainActor
@Observable
final class ChatStore {
    let thread: ChatThread
    var messages: LoadState<[Message]> = .idle
    var composerText = ""
    var partnerIsTyping = false
    var showDealFlow = false
    /// Set when this thread already has money in escrow.
    var hasEscrow = false

    private let repository: any RefindRepository
    private var activityTask: Task<Void, Never>?

    init(thread: ChatThread, repository: any RefindRepository) {
        self.thread = thread
        self.repository = repository
    }

    func load() async {
        if messages.value == nil { messages = .loading }
        do {
            messages = .loaded(try await repository.messages(threadID: thread.id))
            try? await repository.markRead(threadID: thread.id)
        } catch {
            messages = .failed((error as? RepositoryError)?.inlineMessage
                               ?? RepositoryError.server.inlineMessage)
        }
    }

    func watchPartner() {
        activityTask?.cancel()
        activityTask = Task { [repository, thread] in
            for await activity in repository.partnerActivity(threadID: thread.id) {
                guard !Task.isCancelled else { return }
                partnerIsTyping = activity == .typing
            }
        }
    }

    func refreshEscrow() async {
        hasEscrow = ((try? await repository.escrow(forThread: thread.id)) ?? nil) != nil
    }

    func stopWatching() {
        activityTask?.cancel()
        activityTask = nil
        partnerIsTyping = false
    }

    func send() async {
        let body = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        composerText = ""
        _ = try? await repository.send(MessageDraft(threadID: thread.id, kind: .text, body: body))
        await load()
    }

    func attach(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = await item.refindImageData() else { continue }
            let photo = PhotoRef(id: "chat-\(UUID().uuidString.prefix(8))", localData: data)
            _ = try? await repository.send(
                MessageDraft(threadID: thread.id, kind: .photo(photo), body: "")
            )
        }
        await load()
    }
}

struct ChatScreen: View {
    let thread: ChatThread
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var store: ChatStore?
    @State private var picked: [PhotosPickerItem] = []
    @State private var showReport = false
    @State private var showBlockConfirm = false

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            if let store { content(store) }
        }
        .navigationBarBackButtonHidden()
        .task {
            let store = store ?? ChatStore(thread: thread, repository: environment.repository)
            self.store = store
            await store.load()
            await store.refreshEscrow()
            store.watchPartner()
        }
        .onDisappear { store?.stopWatching() }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty, let store else { return }
            Task { await store.attach(items); picked = [] }
        }
    }

    private func content(_ store: ChatStore) -> some View {
        VStack(spacing: 0) {
            header
            thread(store)
            composer(store)
        }
        .padding(.top, 58)
        .fullScreenCover(isPresented: Binding(get: { store.showDealFlow },
                                              set: { store.showDealFlow = $0 })) {
            DealFlow(thread: thread)
                .environment(environment)
                .onDisappear { Task { await store.refreshEscrow() } }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(subject: .user(thread.partner.id),
                        subjectName: thread.partner.displayName)
                .environment(environment)
        }
        .alert("\(thread.partner.displayName) blockieren?",
               isPresented: $showBlockConfirm) {
            Button("Abbrechen", role: .cancel) {}
            Button("Blockieren", role: .destructive) {
                Task {
                    try? await environment.repository.setBlocked(
                        userID: thread.partner.id, blocked: true
                    )
                    dismiss()
                }
            }
        } message: {
            Text("Ihr seht einander nicht mehr. Offene Treuhand-Zahlungen bleiben bestehen.")
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("‹")
                        .font(RF.ui(22))
                        .foregroundStyle(RF.Palette.muted)
                        .frame(minWidth: RF.Metric.minHitTarget,
                               minHeight: RF.Metric.minHitTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zurück")

                RFAvatar(user: thread.partner, size: RF.Metric.avatarChatHeader)

                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.partner.displayName)
                        .font(RF.ui(15, weight: .semibold))
                        .foregroundStyle(RF.Palette.ink)
                    Text(thread.partner.trustLine).rfLabel(10, tracking: 0.6)
                }
                Spacer()
                Text(thread.offerPrice.formatted)
                    .font(RF.num(13, weight: .medium))
                    .foregroundStyle(RF.Palette.offer)
                Menu {
                    Button("\(thread.partner.displayName) melden") { showReport = true }
                    Button("\(thread.partner.displayName) blockieren", role: .destructive) {
                        showBlockConfirm = true
                    }
                } label: {
                    Text("···")
                        .font(RF.ui(17))
                        .foregroundStyle(RF.Palette.muted)
                        .frame(width: RF.Metric.minHitTarget,
                               height: RF.Metric.minHitTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Mehr")
                .accessibilityIdentifier("chat.more")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            Rectangle().fill(RF.Palette.line).frame(height: RF.Metric.hairline)
        }
        .background(RF.Palette.paper.opacity(RF.Metric.barOpacity))
    }

    @ViewBuilder
    private func thread(_ store: ChatStore) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    switch store.messages {
                    case .idle, .loading:
                        ProgressView().tint(RF.Palette.muted).padding(.top, 40)
                    case .loaded(let messages):
                        ForEach(messages) { message in
                            MessageBubble(message: message,
                                          currentUserID: environment.currentUser?.id
                                              ?? MockSeed.me.id)
                                .id(message.id)
                        }
                        if store.partnerIsTyping {
                            HStack {
                                RFTypingDots()
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 4)
                                Spacer()
                            }
                            .id("typing")
                        }
                    case .failed(let message):
                        RFErrorState(message: message) { Task { await store.load() } }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.messages.value?.count) { _, _ in
                if let last = store.messages.value?.last {
                    withAnimation(RF.Motion.entrance) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func composer(_ store: ChatStore) -> some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            Rectangle().fill(RF.Palette.line).frame(height: RF.Metric.hairline)
            HStack(spacing: 10) {
                RFPhotoPicker(selection: $picked, maxCount: 1) {
                    Text("+")
                        .font(RF.ui(20))
                        .foregroundStyle(RF.Palette.muted)
                        .frame(width: 40, height: 40)
                        .background(RF.Palette.card, in: Circle())
                        .overlay { Circle().strokeBorder(RF.Palette.line, lineWidth: 1) }
                }
                .accessibilityLabel("Foto anhängen")

                TextField("Nachricht", text: $store.composerText)
                    .font(RF.ui(14))
                    .tint(RF.Palette.offer)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RF.Palette.card, in: Capsule())
                    .overlay { Capsule().strokeBorder(RF.Palette.line, lineWidth: 1) }
                    .submitLabel(.send)
                    .onSubmit { Task { await store.send() } }

                Button(store.hasEscrow ? "Treuhand" : "Deal") { store.showDealFlow = true }
                    .font(RF.ui(13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(RF.Palette.offer, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat.deal")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(RF.Palette.paper.opacity(RF.Metric.barOpacity))
    }
}

// MARK: - Bubble

struct MessageBubble: View {
    let message: Message
    let currentUserID: String

    private var isMine: Bool { message.isMine(currentUserID: currentUserID) }

    var body: some View {
        switch message.kind {
        case .system:
            Text(message.body)
                .rfLabel(10, tracking: 0.6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RF.Palette.card)
                .overlay { Rectangle().strokeBorder(RF.Palette.line, lineWidth: 1) }
                .frame(maxWidth: .infinity)

        case .photo(let photo):
            HStack {
                if isMine { Spacer(minLength: 40) }
                RFPhoto(photo: photo, cornerRadius: RF.Metric.photoAttachmentRadius)
                    .frame(width: RF.Metric.photoAttachmentWidth,
                           height: RF.Metric.photoAttachmentHeight)
                if !isMine { Spacer(minLength: 40) }
            }
            .accessibilityLabel(isMine ? "Dein Foto" : "Foto erhalten")

        case .text:
            HStack {
                if isMine { Spacer(minLength: 40) }
                Text(message.body)
                    .font(RF.ui(14))
                    .lineSpacing(3)
                    .foregroundStyle(isMine ? RF.Palette.paper : RF.Palette.ink)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background {
                        bubbleShape
                            .fill(isMine ? RF.Palette.ink : RF.Palette.card)
                    }
                    .overlay {
                        if !isMine {
                            bubbleShape.strokeBorder(RF.Palette.line, lineWidth: 1)
                        }
                    }
                if !isMine { Spacer(minLength: 40) }
            }
        }
    }

    /// Outgoing 18 18 4 18, incoming 18 18 18 4 — the 4 pt corner is the tail.
    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: RF.Metric.bubbleRadius,
            bottomLeadingRadius: isMine ? RF.Metric.bubbleRadius : RF.Metric.bubbleTail,
            bottomTrailingRadius: isMine ? RF.Metric.bubbleTail : RF.Metric.bubbleRadius,
            topTrailingRadius: RF.Metric.bubbleRadius
        )
    }
}

#Preview("11 Chat") {
    NavigationStack {
        ChatScreen(thread: MockSeed.threads[0])
            .environment(AppEnvironment.preview)
    }
}
