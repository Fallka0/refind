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
    func republishWant(id: String) async throws -> Want
    func setWantPaused(id: String, paused: Bool) async throws -> Want

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
    func proposeDeal(_ draft: DealDraft) async throws -> Deal
    /// Mock: no payment SDK, no charge. Simulated with local state and delays.
    func startEscrow(dealID: String, method: PaymentMethod) async throws -> Escrow
    func confirmEscrowPayment(id: String) async throws -> Escrow
    func releaseEscrow(id: String) async throws -> Escrow
}
