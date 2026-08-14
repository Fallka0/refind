//
//  LiveRefindRepository.swift
//  refind
//
//  The same protocol every screen already uses, over HTTP per docs/API.md.
//
//  No server implements this yet. It is here so the contract is executable
//  rather than a document nobody checks: if the API changes shape, this stops
//  compiling. Swap it in via AppEnvironment and nothing else changes.
//

import Foundation

actor LiveRefindRepository: RefindRepository {

    private let api: RefindAPI

    init(api: RefindAPI = RefindAPI()) {
        self.api = api
    }

    // MARK: Session

    func currentUser() async throws -> User {
        let dto: UserDTO = try await api.get("me")
        return dto.domain
    }

    func profileStats() async throws -> ProfileStats {
        let dto: StatsDTO = try await api.get("me/stats")
        return dto.domain
    }

    // MARK: Wants

    func myWants() async throws -> [Want] {
        let page: PageDTO<WantDTO> = try await api.get("wants/mine")
        return page.items.map(\.domain)
    }

    func savedWants() async throws -> [Want] {
        let page: PageDTO<WantDTO> = try await api.get("wants/saved")
        return page.items.map(\.domain)
    }

    func discoverWants(category: Category?, query: String) async throws -> [Want] {
        let page: PageDTO<WantDTO> = try await api.get(
            "wants/discover",
            query: ["category": category?.rawValue ?? "", "q": query]
        )
        return page.items.map(\.domain)
    }

    func want(id: String) async throws -> Want {
        let dto: WantDTO = try await api.get("wants/\(id)")
        return dto.domain
    }

    func titleSuggestions(prefix: String) async throws -> [String] {
        guard prefix.trimmingCharacters(in: .whitespaces).count >= 2 else { return [] }
        struct Response: Decodable { let items: [String] }
        let response: Response = try await api.get("wants/suggestions", query: ["q": prefix])
        return response.items
    }

    func createWant(_ draft: WantDraft) async throws -> Want {
        let dto: WantDTO = try await api.post("wants", body: WantDraftDTO(draft))
        return dto.domain
    }

    func updateWant(id: String, draft: WantDraft) async throws -> Want {
        let dto: WantDTO = try await api.patch("wants/\(id)", body: WantDraftDTO(draft))
        return dto.domain
    }

    func republishWant(id: String) async throws -> Want {
        let dto: WantDTO = try await api.post("wants/\(id)/republish", body: EmptyBody())
        return dto.domain
    }

    func setWantPaused(id: String, paused: Bool) async throws -> Want {
        struct Body: Encodable { let paused: Bool }
        let dto: WantDTO = try await api.post("wants/\(id)/pause", body: Body(paused: paused))
        return dto.domain
    }

    func setWantSaved(id: String, saved: Bool) async throws {
        struct Body: Encodable { let saved: Bool }
        try await api.putNoContent("wants/\(id)/saved", body: Body(saved: saved))
    }

    /// Server-side truth only — there is no local cache to answer from, and
    /// guessing here would flicker the save control.
    func isSaved(wantID: String) async -> Bool {
        let saved = try? await savedWants()
        return saved?.contains { $0.id == wantID } ?? false
    }

    // MARK: Offers

    func offers(forWant wantID: String, sort: OfferSort) async throws -> [Offer] {
        let page: PageDTO<OfferDTO> = try await api.get(
            "wants/\(wantID)/offers", query: ["sort": sort.wireValue]
        )
        return page.items.map(\.domain)
    }

    func sendOffer(_ draft: OfferDraft) async throws -> Offer {
        // Photos upload out of band first; the offer only carries their ids.
        let uploaded = try await uploadPhotos(draft.photos)
        var body = draft
        body.photos = uploaded
        let dto: OfferDTO = try await api.post("wants/\(draft.wantID)/offers",
                                               body: OfferDraftDTO(body))
        return dto.domain
    }

    func acceptOffer(id: String) async throws -> ChatThread {
        struct Response: Decodable { let thread: ThreadDTO }
        let response: Response = try await api.post("offers/\(id)/accept", body: EmptyBody())
        return response.thread.domain
    }

    // MARK: Chat

    func threads() async throws -> [ChatThread] {
        let page: PageDTO<ThreadDTO> = try await api.get("threads")
        return page.items.map(\.domain)
    }

    func messages(threadID: String) async throws -> [Message] {
        let page: PageDTO<MessageDTO> = try await api.get("threads/\(threadID)/messages")
        return page.items.map(\.domain).sorted { $0.createdAt < $1.createdAt }
    }

    func send(_ draft: MessageDraft) async throws -> Message {
        struct Body: Encodable {
            let kind: String
            let body: String
            let photoId: String?
        }
        var photoID: String?
        if case .photo(let photo) = draft.kind {
            photoID = try await uploadPhotos([photo]).first?.id
        }
        let dto: MessageDTO = try await api.post(
            "threads/\(draft.threadID)/messages",
            body: Body(kind: draft.kind.wireValue, body: draft.body, photoId: photoID)
        )
        return dto.domain
    }

    func markRead(threadID: String) async throws {
        try await api.postNoContent("threads/\(threadID)/read")
    }

    /// Bridges the thread socket's `typing` frames onto the same stream the
    /// chat screen already consumes.
    nonisolated func partnerActivity(threadID: String) -> AsyncStream<PartnerActivity> {
        AsyncStream { continuation in
            let task = Task {
                // Socket wiring lands with the backend; until then the stream
                // simply stays quiet rather than inventing typing that is not
                // happening.
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Deals and escrow

    func deal(id: String) async throws -> Deal {
        let dto: DealDTO = try await api.get("deals/\(id)")
        return dto.domain
    }

    func deal(forThread threadID: String) async throws -> Deal? {
        do {
            let dto: DealDTO = try await api.get("threads/\(threadID)/deal")
            return dto.domain
        } catch RepositoryError.notFound {
            return nil
        }
    }

    func proposeDeal(_ draft: DealDraft) async throws -> Deal {
        struct Body: Encodable {
            let price: MoneyDTO
            let handoverAt: Date
            let handoverPlace: String
        }
        let dto: DealDTO = try await api.post(
            "threads/\(draft.threadID)/deal",
            body: Body(price: MoneyDTO(draft.finalPrice),
                       handoverAt: draft.handoverAt,
                       handoverPlace: draft.handoverPlace)
        )
        return dto.domain
    }

    func startEscrow(dealID: String, method: PaymentMethod) async throws -> Escrow {
        struct Body: Encodable { let method: String }
        let dto: EscrowDTO = try await api.post("deals/\(dealID)/escrow",
                                                body: Body(method: method.rawValue))
        return dto.domain
    }

    func confirmEscrowPayment(id: String) async throws -> Escrow {
        struct Body: Encodable { let paymentToken: String }
        // The token comes from whichever payment provider is chosen — see the
        // open questions in docs/API.md.
        let dto: EscrowDTO = try await api.post("escrows/\(id)/authorise",
                                                body: Body(paymentToken: ""))
        return dto.domain
    }

    func confirmHandover(escrowID: String) async throws -> Escrow {
        let dto: EscrowDTO = try await api.post("escrows/\(escrowID)/handover",
                                                body: EmptyBody())
        return dto.domain
    }

    func releaseEscrow(id: String) async throws -> Escrow {
        let dto: EscrowDTO = try await api.post("escrows/\(id)/release", body: EmptyBody())
        return dto.domain
    }

    func escrow(forThread threadID: String) async throws -> Escrow? {
        guard let deal = try await deal(forThread: threadID) else { return nil }
        do {
            let dto: EscrowDTO = try await api.get("deals/\(deal.id)/escrow")
            return dto.domain
        } catch RepositoryError.notFound {
            return nil
        }
    }

    func rate(dealID: String, stars: Int) async throws {
        struct Body: Encodable { let stars: Int }
        try await api.postNoContent("deals/\(dealID)/rating", body: Body(stars: stars))
    }

    func openDispute(escrowID: String, reason: DisputeReason,
                     detail: String) async throws -> Escrow {
        struct Body: Encodable { let reason: String; let detail: String }
        let dto: EscrowDTO = try await api.post(
            "escrows/\(escrowID)/dispute",
            body: Body(reason: reason.rawValue, detail: detail)
        )
        return dto.domain
    }

    // MARK: Safety

    func report(_ subject: ReportSubject, reason: ReportReason, detail: String) async throws {
        try await api.postNoContent("reports", body: ReportDTO(
            subjectType: subject.wireType, subjectId: subject.id,
            reason: reason.rawValue, detail: detail
        ))
    }

    func setBlocked(userID: String, blocked: Bool) async throws {
        if blocked {
            try await api.putNoContent("blocks/\(userID)", body: EmptyBody())
        } else {
            try await api.deleteNoContent("blocks/\(userID)")
        }
    }

    func blockedUsers() async throws -> [User] {
        let page: PageDTO<UserDTO> = try await api.get("blocks")
        return page.items.map(\.domain)
    }

    // MARK: Verification

    func verificationStatus() async throws -> VerificationStatus {
        let dto: VerificationDTO = try await api.get("me/verification")
        return dto.domain
    }

    func startVerification() async throws -> URL {
        struct Response: Decodable { let sessionId: String; let providerURL: URL }
        let response: Response = try await api.post("me/verification/session",
                                                    body: EmptyBody())
        return response.providerURL
    }

    // MARK: Push

    func registerDevice(token: String, sandbox: Bool) async throws {
        struct Body: Encodable { let token: String; let environment: String; let locale: String }
        try await api.putNoContent("me/devices", body: Body(
            token: token,
            environment: sandbox ? "sandbox" : "production",
            locale: Locale.current.identifier
        ))
    }

    // MARK: Helpers

    private struct EmptyBody: Encodable {}

    /// Two-step upload: reserve, PUT the bytes, keep the returned id.
    private func uploadPhotos(_ photos: [PhotoRef]) async throws -> [PhotoRef] {
        var result: [PhotoRef] = []
        for photo in photos {
            guard let data = photo.localData else {
                result.append(photo)   // already on the server
                continue
            }
            struct Request: Encodable { let contentType: String; let byteSize: Int }
            struct Response: Decodable {
                let photoId: String
                let uploadURL: URL
                let headers: [String: String]
            }
            let reservation: Response = try await api.post(
                "uploads", body: Request(contentType: "image/jpeg", byteSize: data.count)
            )
            var request = URLRequest(url: reservation.uploadURL)
            request.httpMethod = "PUT"
            for (key, value) in reservation.headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            _ = try? await URLSession.shared.upload(for: request, from: data)
            result.append(PhotoRef(id: reservation.photoId))
        }
        return result
    }
}

// MARK: - Wire values

extension OfferSort {
    var wireValue: String {
        switch self {
        case .priceAscending:  return "price_asc"
        case .priceDescending: return "price_desc"
        case .newest:          return "newest"
        }
    }
}

extension Message.Kind {
    var wireValue: String {
        switch self {
        case .text:   return "text"
        case .photo:  return "photo"
        case .system: return "system"
        }
    }
}
