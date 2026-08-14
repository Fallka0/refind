//
//  DealStore.swift
//  refind
//
//  Drives screens 14–18. Everything here is a simulation: no payment SDK, no
//  card is ever charged, the "authorisation" is a sleep.
//

import SwiftUI

@MainActor
@Observable
final class DealStore {

    let thread: ChatThread
    var deal: Deal?
    var method: PaymentMethod = .escrow
    var escrow: Escrow?

    var cardNumber = ""
    var expiry = ""
    var cvc = ""
    var saveCard = true

    var isWorking = false
    var errorMessage: String?

    private let repository: any RefindRepository

    init(thread: ChatThread, repository: any RefindRepository) {
        self.thread = thread
        self.repository = repository
    }

    /// The handover terms the two sides agreed in chat. A real product would
    /// carry these from the conversation; the mocks fix them at Sa 14:00 · Zürich HB.
    func prepareDeal() async {
        guard deal == nil else { return }
        isWorking = true
        defer { isWorking = false }
        // Prefer the deal the two sides already agreed — its price is the
        // negotiated one, which is what every payment screen must show. The
        // handoff's flow says both sides confirm price and handover, but that
        // step is not drawn, so proposing falls back to the offer price.
        // `try?` on an optional-returning call nests the optionals; flatten it.
        if let agreed = (try? await repository.deal(forThread: thread.id)) ?? nil {
            deal = agreed
            return
        }
        deal = try? await repository.proposeDeal(
            DealDraft(threadID: thread.id,
                      finalPrice: thread.offerPrice,
                      handoverAt: MockSeed.nextSaturdayAtTwo,
                      handoverPlace: "Zürich HB")
        )
    }

    var amount: Money { deal?.finalPrice ?? thread.offerPrice }
    var fee: Money { method == .escrow ? Escrow.fee(on: amount) : .zero }
    var total: Money { amount + fee }
    var partnerName: String { thread.partner.displayName }
    /// "Marc" — the mocks address people by first name in body copy.
    var partnerFirstName: String {
        thread.partner.displayName.split(separator: " ").first.map(String.init)
            ?? thread.partner.displayName
    }

    var cardIsValid: Bool { cardNumber.filter(\.isNumber).count >= 12 }

    func startEscrow() async -> Bool {
        guard let deal else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            escrow = try await repository.startEscrow(dealID: deal.id, method: method)
            return true
        } catch {
            errorMessage = (error as? RepositoryError)?.inlineMessage
                ?? RepositoryError.server.inlineMessage
            return false
        }
    }

    /// The buyer has the item — unlocks release.
    func confirmHandover() async {
        guard let escrow else { return }
        isWorking = true
        defer { isWorking = false }
        if let moved = try? await repository.confirmHandover(escrowID: escrow.id) {
            self.escrow = moved
        }
    }

    /// "Geld freigeben" — the seller gets paid.
    func release() async {
        guard let escrow else { return }
        isWorking = true
        defer { isWorking = false }
        if let moved = try? await repository.releaseEscrow(id: escrow.id) {
            self.escrow = moved
        }
    }

    func loadExistingEscrow() async {
        escrow = (try? await repository.escrow(forThread: thread.id)) ?? nil
    }

    /// The fake authorisation behind the Face ID sheet.
    func authorise() async -> Bool {
        guard let escrow else { return false }
        isWorking = true
        defer { isWorking = false }
        let confirmed = try? await repository.confirmEscrowPayment(id: escrow.id)
        guard let confirmed else {
            errorMessage = RepositoryError.server.inlineMessage
            return false
        }
        self.escrow = confirmed
        return true
    }
}
