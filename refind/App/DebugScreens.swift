//
//  DebugScreens.swift
//  refind
//
//  Debug-only launch hatch so any screen can be opened directly, without
//  tapping through the flow that leads to it:
//
//      SIMCTL_CHILD_RF_SCREEN=post-review xcrun simctl launch <udid> planary.refind
//
//  Compiled out of release builds entirely.
//

import SwiftUI

#if DEBUG
enum DebugScreen: String {
    case gallery
    case postTitle    = "post-title"
    case postDetails  = "post-details"
    case postReview   = "post-review"
    case postLive     = "post-live"
    case homeEmpty    = "home-empty"
    case homeError    = "home-error"
    case homeLoading  = "home-loading"
    case wantDetail   = "want-detail"
    case discover     = "discover"
    case sendOffer    = "send-offer"
    case chats        = "chats"
    case chat         = "chat"
    case payMethod    = "pay-method"
    case payCard      = "pay-card"
    case payConfirm   = "pay-confirm"
    case escrowDone   = "escrow-done"
    case dealDone     = "deal-done"
    case escrowInfo   = "escrow-info"
    case splash       = "splash"
    case onboarding   = "onboarding"
    case profile      = "profile"

    static var requested: DebugScreen? {
        guard let raw = ProcessInfo.processInfo.environment["RF_SCREEN"] else { return nil }
        return DebugScreen(rawValue: raw)
    }
}

struct DebugScreenHost: View {
    let screen: DebugScreen

    var body: some View {
        switch screen {
        case .gallery:
            TokenGallery()
        case .postTitle:
            PostTitleStep(store: seededStore(), onCancel: {}, onNext: {})
        case .postDetails:
            PostDetailsStep(store: seededStore(), onBack: {}, onNext: {})
        case .postReview:
            PostReviewStep(store: seededStore(), onBack: {}, onSubmit: {})
        case .postLive:
            WantLiveScreen(want: MockSeed.omegaWant, onDone: {})
        case .discover:
            DiscoverScreen()
                .environment(AppEnvironment.preview)
        case .sendOffer:
            SendOfferSheet(want: MockSeed.eamesWant, recipient: MockSeed.nina)
                .environment(AppEnvironment.preview)
        case .chats:
            NavigationStack { ChatsScreen().environment(AppEnvironment.preview) }
        case .chat:
            NavigationStack {
                ChatScreen(thread: MockSeed.threads[0]).environment(AppEnvironment.preview)
            }
        case .payMethod:
            PaymentMethodStep(store: dealStore(), onBack: {}, onNext: {})
        case .payCard:
            CardStep(store: dealStore(), onBack: {}, onNext: {})
        case .payConfirm:
            ConfirmPayStep(store: dealStore(), onBack: {}, onPaid: {})
        case .escrowInfo:
            EscrowExplainerSheet(store: dealStore())
        case .escrowDone:
            EscrowActiveScreen(store: paidStore(), onBackToChat: {})
        case .dealDone:
            DealConfirmedScreen(store: dealStore(), onDone: {})
        case .splash:
            SplashScreen()
        case .onboarding:
            OnboardingFlow()
        case .profile:
            ProfileScreen().environment(AppEnvironment.preview)
        case .wantDetail:
            NavigationStack {
                WantDetailScreen(wantID: MockSeed.omegaWant.id)
                    .environment(AppEnvironment.preview)
            }
        case .homeEmpty, .homeError, .homeLoading:
            HomeScreen()
                .environment(AppEnvironment(repository: repository(for: screen)))
        }
    }

    private func seededStore() -> PostWantStore {
        let store = PostWantStore(repository: MockRefindRepository.instant, city: "Zürich")
        store.draft.title = "Omega Seamaster 166.062"
        store.inferCategory()
        return store
    }

    private func dealStore() -> DealStore {
        let store = DealStore(thread: MockSeed.threads[0],
                              repository: MockRefindRepository.instant)
        // The agreed price, not the opening offer — what the payment screens show.
        store.deal = MockSeed.marcDeal
        return store
    }

    private func paidStore() -> DealStore {
        let store = dealStore()
        store.escrow = Escrow(id: "e-preview", dealID: "d-marc", method: .escrow,
                              amount: Money(chf: 1_650),
                              fee: Escrow.fee(on: Money(chf: 1_650)),
                              receiptNumber: MockSeed.receiptNumber,
                              paidAt: .now, stage: .paid)
        return store
    }

    private func repository(for screen: DebugScreen) -> any RefindRepository {
        switch screen {
        case .homeError:
            return MockRefindRepository(latency: .zero, failure: .offline)
        case .homeLoading:
            // Long enough to screenshot the skeletons.
            return MockRefindRepository(latency: .seconds(30))
        default:
            return EmptyRefindRepository()
        }
    }
}

/// Every list empty — the empty states, without editing the seed.
private struct EmptyRefindRepository: RefindRepository {
    private let base = MockRefindRepository.instant

    func currentUser() async throws -> User { MockSeed.me }
    func profileStats() async throws -> ProfileStats {
        ProfileStats(rating: 0, dealCount: 0, liveWantCount: 0)
    }
    func myWants() async throws -> [Want] { [] }
    func savedWants() async throws -> [Want] { [] }
    func discoverWants(category: Category?, query: String) async throws -> [Want] { [] }
    func want(id: String) async throws -> Want { throw RepositoryError.notFound }
    func titleSuggestions(prefix: String) async throws -> [String] { [] }
    func createWant(_ draft: WantDraft) async throws -> Want { try await base.createWant(draft) }
    func updateWant(id: String, draft: WantDraft) async throws -> Want {
        try await base.updateWant(id: id, draft: draft)
    }
    func setWantSaved(id: String, saved: Bool) async throws {}
    func isSaved(wantID: String) async -> Bool { false }
    func republishWant(id: String) async throws -> Want { throw RepositoryError.notFound }
    func setWantPaused(id: String, paused: Bool) async throws -> Want { throw RepositoryError.notFound }
    func offers(forWant wantID: String, sort: OfferSort) async throws -> [Offer] { [] }
    func sendOffer(_ draft: OfferDraft) async throws -> Offer { try await base.sendOffer(draft) }
    func acceptOffer(id: String) async throws -> ChatThread { throw RepositoryError.notFound }
    func threads() async throws -> [ChatThread] { [] }
    func messages(threadID: String) async throws -> [Message] { [] }
    func send(_ draft: MessageDraft) async throws -> Message { try await base.send(draft) }
    func markRead(threadID: String) async throws {}
    nonisolated func partnerActivity(threadID: String) -> AsyncStream<PartnerActivity> {
        AsyncStream { $0.finish() }
    }
    func deal(id: String) async throws -> Deal { throw RepositoryError.notFound }
    func deal(forThread threadID: String) async throws -> Deal? { nil }
    func proposeDeal(_ draft: DealDraft) async throws -> Deal { throw RepositoryError.notFound }
    func startEscrow(dealID: String, method: PaymentMethod) async throws -> Escrow {
        throw RepositoryError.notFound
    }
    func confirmEscrowPayment(id: String) async throws -> Escrow { throw RepositoryError.notFound }
    func confirmHandover(escrowID: String) async throws -> Escrow { throw RepositoryError.notFound }
    func releaseEscrow(id: String) async throws -> Escrow { throw RepositoryError.notFound }
    func escrow(forThread threadID: String) async throws -> Escrow? { nil }
    func rate(dealID: String, stars: Int) async throws {}
}
#endif
