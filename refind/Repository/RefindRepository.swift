//
//  RefindRepository.swift
//  refind
//
//  The one seam between screens and data. There is no backend yet;
//  MockRefindRepository is the only implementation. A live one drops in behind
//  this protocol without a screen changing.
//

import Foundation

protocol RefindRepository: Sendable {

    // MARK: Session
    func currentUser() async throws -> User
    func profileStats() async throws -> ProfileStats

    // MARK: Wants
    func myWants() async throws -> [Want]
    func savedWants() async throws -> [Want]
    func discoverWants(category: Category?, query: String) async throws -> [Want]
    func want(id: String) async throws -> Want
    func titleSuggestions(prefix: String) async throws -> [String]
    func createWant(_ draft: WantDraft) async throws -> Want
    func updateWant(id: String, draft: WantDraft) async throws -> Want
    func republishWant(id: String) async throws -> Want
    func setWantPaused(id: String, paused: Bool) async throws -> Want
    func setWantSaved(id: String, saved: Bool) async throws
    func isSaved(wantID: String) async -> Bool

    // MARK: Offers
    func offers(forWant wantID: String, sort: OfferSort) async throws -> [Offer]
    func sendOffer(_ draft: OfferDraft) async throws -> Offer
    /// Accepting an offer informs the other sellers and opens the thread.
    func acceptOffer(id: String) async throws -> ChatThread

    // MARK: Chat
    func threads() async throws -> [ChatThread]
    func messages(threadID: String) async throws -> [Message]
    func send(_ draft: MessageDraft) async throws -> Message
    func markRead(threadID: String) async throws
    /// Drives the typing indicator.
    func partnerActivity(threadID: String) -> AsyncStream<PartnerActivity>

    // MARK: Deal and mock escrow
    func deal(id: String) async throws -> Deal
    /// The deal already agreed in a thread, if there is one. The negotiated
    /// price lives here — it is not the offer's opening price.
    func deal(forThread threadID: String) async throws -> Deal?
    func proposeDeal(_ draft: DealDraft) async throws -> Deal
    /// Mock: no payment SDK, no charge. Simulated with local state and delays.
    func startEscrow(dealID: String, method: PaymentMethod) async throws -> Escrow
    func confirmEscrowPayment(id: String) async throws -> Escrow
    /// The buyer confirming they have the item in hand — what unlocks release.
    func confirmHandover(escrowID: String) async throws -> Escrow
    func releaseEscrow(id: String) async throws -> Escrow
    func escrow(forThread threadID: String) async throws -> Escrow?
    func rate(dealID: String, stars: Int) async throws
}
