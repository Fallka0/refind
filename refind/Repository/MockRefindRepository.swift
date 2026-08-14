//
//  MockRefindRepository.swift
//  refind
//
//  In-memory implementation seeded from MockSeed. An actor so mutations from
//  several screens cannot race.
//
//  `latency` and `failure` are the reason this exists in this shape: the
//  skeleton, empty and error states of every list are reachable from a preview
//  or a test by flipping a knob, instead of being faked per screen.
//

import Foundation

actor MockRefindRepository: RefindRepository {

    // MARK: Configuration

    /// Simulated round trip. `.zero` for tests and previews that want content immediately.
    var latency: Duration
    /// When set, every call throws it — drives the error state.
    var failure: RepositoryError?

    init(latency: Duration = .milliseconds(450), failure: RepositoryError? = nil) {
        self.latency = latency
        self.failure = failure
    }

    /// The app's default: visible latency so the skeletons actually show.
    static let demo = MockRefindRepository()
    /// No delay — previews and snapshot tests.
    static let instant = MockRefindRepository(latency: .zero)
    /// Everything fails — the error state.
    static let failing = MockRefindRepository(latency: .milliseconds(200), failure: .offline)

    func setLatency(_ latency: Duration) { self.latency = latency }
    func setFailure(_ failure: RepositoryError?) { self.failure = failure }

    // MARK: State

    private var wants: [Want] = MockSeed.allWants
    private var offerStore: [Offer] = MockSeed.offers
    private var threadStore: [ChatThread] = MockSeed.threads
    private var messageStore: [String: [Message]] = MockSeed.messages
    private var deals: [Deal] = [MockSeed.marcDeal]
    private var escrows: [Escrow] = []
    private var savedIDs: Set<String> = []
    private var blockedIDs: Set<String> = []
    private var reports: [String] = []
    private var disputes: [String: String] = [:]
    private var deviceTokens: Set<String> = []
    private var verification: VerificationStatus = .unverified
    private var ratings: [String: Int] = [:]
    private var nextID = 1

    private func mintID(_ prefix: String) -> String {
        defer { nextID += 1 }
        return "\(prefix)-\(nextID)"
    }

    private func hop() async throws {
        if latency > .zero { try? await Task.sleep(for: latency) }
        if let failure { throw failure }
    }

    // MARK: Session

    func currentUser() async throws -> User {
        try await hop()
        return MockSeed.me
    }

    func profileStats() async throws -> ProfileStats {
        try await hop()
        let live = wants.filter { $0.ownerID == MockSeed.me.id && $0.isLive }.count
        return ProfileStats(rating: MockSeed.me.rating,
                            dealCount: MockSeed.me.dealCount,
                            liveWantCount: live)
    }

    // MARK: Wants

    func myWants() async throws -> [Want] {
        try await hop()
        return wants
            .filter { $0.ownerID == MockSeed.me.id }
            .sorted { rank($0) < rank($1) }
    }

    /// Live wants first, then paused, expired last; newest first inside a group.
    private func rank(_ want: Want) -> (Int, TimeInterval) {
        let group: Int
        switch want.status {
        case .live:      group = 0
        case .paused:    group = 1
        case .fulfilled: group = 2
        case .expired:   group = 3
        }
        return (group, -want.createdAt.timeIntervalSince1970)
    }

    func savedWants() async throws -> [Want] {
        try await hop()
        return wants.filter { savedIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func setWantSaved(id: String, saved: Bool) async throws {
        try await hop()
        if saved { savedIDs.insert(id) } else { savedIDs.remove(id) }
    }

    func isSaved(wantID: String) async -> Bool { savedIDs.contains(wantID) }

    func updateWant(id: String, draft: WantDraft) async throws -> Want {
        guard draft.titleIsValid else {
            throw RepositoryError.invalidInput("Der Titel braucht mindestens 3 Zeichen.")
        }
        guard draft.budgetIsValid else {
            throw RepositoryError.invalidInput("Setz ein Budget zwischen CHF 1 und CHF 100'000.")
        }
        try await hop()
        guard let index = wants.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        let old = wants[index]
        let updated = Want(
            id: old.id, ownerID: old.ownerID,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: draft.category, budgetMax: draft.budgetMax,
            condition: draft.condition, region: draft.region, radiusKm: draft.radiusKm,
            itemDescription: old.itemDescription, createdAt: old.createdAt,
            expiresAt: old.expiresAt, status: old.status,
            offerCount: old.offerCount, unreadOfferCount: old.unreadOfferCount
        )
        wants[index] = updated
        return updated
    }

    func discoverWants(category: Category?, query: String) async throws -> [Want] {
        try await hop()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return wants
            .filter { $0.ownerID != MockSeed.me.id && $0.isLive }
            .filter { !blockedIDs.contains($0.ownerID) }
            .filter { category == nil || $0.category == category }
            .filter { trimmed.isEmpty || $0.title.lowercased().contains(trimmed) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func want(id: String) async throws -> Want {
        try await hop()
        guard let want = wants.first(where: { $0.id == id }) else { throw RepositoryError.notFound }
        return want
    }

    func titleSuggestions(prefix: String) async throws -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 2 else { return [] }
        try await hop()
        return MockSeed.titleCatalog
            .filter { $0.lowercased().contains(trimmed) }
            .prefix(3)
            .map { $0 }
    }

    func createWant(_ draft: WantDraft) async throws -> Want {
        guard draft.titleIsValid else {
            throw RepositoryError.invalidInput("Der Titel braucht mindestens 3 Zeichen.")
        }
        guard draft.budgetIsValid else {
            throw RepositoryError.invalidInput("Setz ein Budget zwischen CHF 1 und CHF 100'000.")
        }
        try await hop()
        let want = Want(
            id: mintID("w"),
            ownerID: MockSeed.me.id,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: draft.category,
            budgetMax: draft.budgetMax,
            condition: draft.condition,
            region: draft.region,
            radiusKm: draft.radiusKm,
            itemDescription: nil,
            createdAt: .now,
            expiresAt: Date.now.addingTimeInterval(Double(draft.durationDays) * 86_400),
            status: .live,
            offerCount: 0,
            unreadOfferCount: 0
        )
        wants.insert(want, at: 0)
        return want
    }

    func republishWant(id: String) async throws -> Want {
        try await hop()
        guard let index = wants.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        let old = wants[index]
        let renewed = Want(
            id: old.id, ownerID: old.ownerID, title: old.title, category: old.category,
            budgetMax: old.budgetMax, condition: old.condition, region: old.region,
            radiusKm: old.radiusKm, itemDescription: old.itemDescription,
            createdAt: .now, expiresAt: Date.now.addingTimeInterval(14 * 86_400),
            status: .live, offerCount: 0, unreadOfferCount: 0
        )
        wants[index] = renewed
        return renewed
    }

    func setWantPaused(id: String, paused: Bool) async throws -> Want {
        try await hop()
        guard let index = wants.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        let old = wants[index]
        let updated = Want(
            id: old.id, ownerID: old.ownerID, title: old.title, category: old.category,
            budgetMax: old.budgetMax, condition: old.condition, region: old.region,
            radiusKm: old.radiusKm, itemDescription: old.itemDescription,
            createdAt: old.createdAt, expiresAt: old.expiresAt,
            status: paused ? .paused : .live,
            offerCount: old.offerCount, unreadOfferCount: old.unreadOfferCount
        )
        wants[index] = updated
        return updated
    }

    // MARK: Offers

    func offers(forWant wantID: String, sort: OfferSort) async throws -> [Offer] {
        try await hop()
        let list = offerStore.filter { $0.wantID == wantID && $0.status != .withdrawn }
        switch sort {
        case .priceAscending:  return list.sorted { $0.price < $1.price }
        case .priceDescending: return list.sorted { $0.price > $1.price }
        case .newest:          return list.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func sendOffer(_ draft: OfferDraft) async throws -> Offer {
        guard draft.priceIsValid else {
            throw RepositoryError.invalidInput("Setz einen Preis über CHF 0.")
        }
        guard draft.messageIsValid else {
            throw RepositoryError.invalidInput("Die Nachricht ist zu lang.")
        }
        try await hop()
        let offer = Offer(
            id: mintID("o"), wantID: draft.wantID, seller: MockSeed.me,
            price: draft.price, message: draft.message, photos: draft.photos,
            createdAt: .now, status: .sent
        )
        offerStore.append(offer)
        bumpOfferCount(wantID: draft.wantID, by: 1)

        // The flow says a thread appears in tab 3 once an offer is sent.
        if let want = wants.first(where: { $0.id == draft.wantID }),
           let owner = MockSeed.people.first(where: { $0.id == want.ownerID }) {
            threadStore.insert(
                ChatThread(id: mintID("t"), offerID: offer.id, wantID: want.id,
                           wantTitle: want.title, offerPrice: offer.price, partner: owner,
                           lastMessage: draft.message.isEmpty ? "Angebot gesendet" : draft.message,
                           lastMessageWasMine: true, lastActivity: .now, unreadCount: 0),
                at: 0
            )
        }
        return offer
    }

    private func bumpOfferCount(wantID: String, by delta: Int) {
        guard let index = wants.firstIndex(where: { $0.id == wantID }) else { return }
        let old = wants[index]
        wants[index] = Want(
            id: old.id, ownerID: old.ownerID, title: old.title, category: old.category,
            budgetMax: old.budgetMax, condition: old.condition, region: old.region,
            radiusKm: old.radiusKm, itemDescription: old.itemDescription,
            createdAt: old.createdAt, expiresAt: old.expiresAt, status: old.status,
            offerCount: old.offerCount + delta, unreadOfferCount: old.unreadOfferCount
        )
    }

    func acceptOffer(id: String) async throws -> ChatThread {
        try await hop()
        guard let index = offerStore.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        let accepted = offerStore[index]
        offerStore[index] = replacing(accepted, status: .accepted)

        // The confirm alert promises the other sellers are informed.
        for (i, other) in offerStore.enumerated()
        where other.wantID == accepted.wantID && other.id != accepted.id && other.status == .sent {
            offerStore[i] = replacing(other, status: .declined)
        }

        if let existing = threadStore.first(where: { $0.offerID == accepted.id } ) {
            return existing
        }
        let thread = ChatThread(
            id: mintID("t"), offerID: accepted.id, wantID: accepted.wantID,
            wantTitle: wants.first(where: { $0.id == accepted.wantID })?.title ?? "",
            offerPrice: accepted.price, partner: accepted.seller,
            lastMessage: "Angebot angenommen", lastMessageWasMine: true,
            lastActivity: .now, unreadCount: 0
        )
        threadStore.insert(thread, at: 0)
        return thread
    }

    private func replacing(_ offer: Offer, status: Offer.Status) -> Offer {
        Offer(id: offer.id, wantID: offer.wantID, seller: offer.seller, price: offer.price,
              message: offer.message, photos: offer.photos, createdAt: offer.createdAt,
              status: status)
    }

    // MARK: Chat

    func threads() async throws -> [ChatThread] {
        try await hop()
        return threadStore.sorted { $0.lastActivity > $1.lastActivity }
    }

    func messages(threadID: String) async throws -> [Message] {
        try await hop()
        return messageStore[threadID, default: []].sorted { $0.createdAt < $1.createdAt }
    }

    func send(_ draft: MessageDraft) async throws -> Message {
        try await hop()
        let message = Message(id: mintID("m"), threadID: draft.threadID,
                              senderID: MockSeed.me.id, kind: draft.kind,
                              body: draft.body, createdAt: .now, readAt: nil)
        messageStore[draft.threadID, default: []].append(message)
        if let index = threadStore.firstIndex(where: { $0.id == draft.threadID }) {
            let old = threadStore[index]
            threadStore[index] = ChatThread(
                id: old.id, offerID: old.offerID, wantID: old.wantID,
                wantTitle: old.wantTitle, offerPrice: old.offerPrice, partner: old.partner,
                lastMessage: draft.body, lastMessageWasMine: true,
                lastActivity: .now, unreadCount: 0
            )
        }
        return message
    }

    func markRead(threadID: String) async throws {
        guard let index = threadStore.firstIndex(where: { $0.id == threadID }) else { return }
        let old = threadStore[index]
        threadStore[index] = ChatThread(
            id: old.id, offerID: old.offerID, wantID: old.wantID, wantTitle: old.wantTitle,
            offerPrice: old.offerPrice, partner: old.partner, lastMessage: old.lastMessage,
            lastMessageWasMine: old.lastMessageWasMine, lastActivity: old.lastActivity,
            unreadCount: 0
        )
        messageStore[threadID] = messageStore[threadID, default: []].map {
            var copy = $0
            if copy.readAt == nil { copy.readAt = .now }
            return copy
        }
    }

    /// nonisolated: the stream touches no actor state, and the protocol
    /// requirement is synchronous.
    nonisolated func partnerActivity(threadID: String) -> AsyncStream<PartnerActivity> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(4))
                    continuation.yield(.typing)
                    try? await Task.sleep(for: .seconds(3))
                    continuation.yield(.idle)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Deal and mock escrow

    func deal(id: String) async throws -> Deal {
        try await hop()
        guard let deal = deals.first(where: { $0.id == id }) else { throw RepositoryError.notFound }
        return deal
    }

    func deal(forThread threadID: String) async throws -> Deal? {
        try await hop()
        return deals.first { $0.threadID == threadID }
    }

    func proposeDeal(_ draft: DealDraft) async throws -> Deal {
        try await hop()
        guard let thread = threadStore.first(where: { $0.id == draft.threadID }) else {
            throw RepositoryError.notFound
        }
        let deal = Deal(
            id: mintID("d"), offerID: thread.offerID, threadID: thread.id,
            wantTitle: thread.wantTitle, partner: thread.partner,
            finalPrice: draft.finalPrice, handoverAt: draft.handoverAt,
            handoverPlace: draft.handoverPlace, ratedByBuyer: false, ratedBySeller: false
        )
        deals.append(deal)
        return deal
    }

    func startEscrow(dealID: String, method: PaymentMethod) async throws -> Escrow {
        try await hop()
        guard let deal = deals.first(where: { $0.id == dealID }) else {
            throw RepositoryError.notFound
        }
        let escrow = Escrow(
            id: mintID("e"), dealID: deal.id, method: method, amount: deal.finalPrice,
            fee: method == .escrow ? Escrow.fee(on: deal.finalPrice) : .zero,
            receiptNumber: MockSeed.receiptNumber, paidAt: .now, stage: .paid
        )
        escrows.append(escrow)
        return escrow
    }

    /// The fake authorisation delay behind the Face ID sheet. Nothing is charged.
    func confirmEscrowPayment(id: String) async throws -> Escrow {
        try? await Task.sleep(for: .milliseconds(1_200))
        if let failure { throw failure }
        guard let index = escrows.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        return escrows[index]
    }

    func confirmHandover(escrowID: String) async throws -> Escrow {
        try await hop()
        return try advance(escrowID, to: .handover)
    }

    func releaseEscrow(id: String) async throws -> Escrow {
        try await hop()
        return try advance(id, to: .released)
    }

    private func advance(_ escrowID: String, to stage: Escrow.Stage) throws -> Escrow {
        guard let index = escrows.firstIndex(where: { $0.id == escrowID }) else {
            throw RepositoryError.notFound
        }
        let old = escrows[index]
        let moved = Escrow(id: old.id, dealID: old.dealID, method: old.method,
                           amount: old.amount, fee: old.fee,
                           receiptNumber: old.receiptNumber, paidAt: old.paidAt,
                           stage: stage)
        escrows[index] = moved
        return moved
    }

    func escrow(forThread threadID: String) async throws -> Escrow? {
        try await hop()
        guard let deal = deals.first(where: { $0.threadID == threadID }) else { return nil }
        return escrows.first { $0.dealID == deal.id }
    }

    func rate(dealID: String, stars: Int) async throws {
        try await hop()
        ratings[dealID] = max(1, min(5, stars))
    }
}

// MARK: - Safety, verification, push

extension MockRefindRepository {

    func openDispute(escrowID: String, reason: DisputeReason,
                     detail: String) async throws -> Escrow {
        try await hop()
        disputes[escrowID] = "\(reason.rawValue): \(detail)"
        // Money stays held. The stage does not advance to released while a
        // dispute is open — that is the whole point of holding it.
        return try advance(escrowID, to: .handover)
    }

    func report(_ subject: ReportSubject, reason: ReportReason, detail: String) async throws {
        try await hop()
        reports.append("\(subject.wireType):\(subject.id) \(reason.rawValue) \(detail)")
    }

    func setBlocked(userID: String, blocked: Bool) async throws {
        try await hop()
        if blocked { blockedIDs.insert(userID) } else { blockedIDs.remove(userID) }
        // Blocking hides both sides immediately, threads included.
        threadStore.removeAll { blocked && $0.partner.id == userID }
    }

    func blockedUsers() async throws -> [User] {
        try await hop()
        return MockSeed.people.filter { blockedIDs.contains($0.id) }
    }

    func verificationStatus() async throws -> VerificationStatus {
        try await hop()
        return verification
    }

    func startVerification() async throws -> URL {
        try await hop()
        verification = .pending
        // A real build hands back the provider's hosted flow.
        return URL(string: "https://verify.refind.ch/session/mock")!
    }

    func registerDevice(token: String, sandbox: Bool) async throws {
        try await hop()
        deviceTokens.insert(token)
    }
}
