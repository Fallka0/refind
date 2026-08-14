//
//  FoundationTests.swift
//  refindTests
//
//  Covers the parts of the foundation that are wrong-in-silence: money and date
//  formatting (a comma instead of an apostrophe reads as a different product)
//  and the mock repository's core behaviour.
//

import Testing
import Foundation
@testable import refind

// MARK: - Money

@Suite("Money")
struct MoneyTests {

    @Test("Swiss apostrophe grouping, no decimals")
    func grouping() {
        #expect(Money(chf: 1_650).formatted == "CHF 1’650")
        #expect(Money(chf: 2_000).formatted == "CHF 2’000")
        #expect(Money(chf: 900).formatted == "CHF 900")
        #expect(Money(chf: 100_000).formatted == "CHF 100’000")
    }

    @Test("Exact form carries Rappen — the escrow totals")
    func exact() {
        #expect(Money(chf: 1_650).formattedExact == "CHF 1’650.00")
        #expect(Money(minorUnits: 4_125).formattedExact == "CHF 41.25")
        #expect(Money(minorUnits: 169_125).formattedExact == "CHF 1’691.25")
    }

    @Test("The 2.5% escrow fee matches the number printed in the designs")
    func escrowFee() {
        let price = Money(chf: 1_650)
        let fee = Escrow.fee(on: price)
        #expect(fee == Money(minorUnits: 4_125))
        #expect(fee.formattedExact == "CHF 41.25")
        #expect((price + fee).formattedExact == "CHF 1’691.25")
    }

    @Test("Ordering is by value, so price sorts are honest")
    func ordering() {
        #expect(Money(chf: 1_720) < Money(chf: 1_890))
        #expect(Money(chf: 2_100) > Money(chf: 1_950))
    }
}

// MARK: - Formatters

@Suite("German formatting")
struct FormatterTests {

    @Test("Relative age, in caps, as the labels need it")
    func age() {
        let now = Date()
        #expect(RF.relativeAge(from: now.addingTimeInterval(-12 * 60), now: now) == "VOR 12 MIN")
        #expect(RF.relativeAge(from: now.addingTimeInterval(-3600), now: now) == "VOR 1 STD")
        #expect(RF.relativeAge(from: now.addingTimeInterval(-3 * 3600), now: now) == "VOR 3 STD")
        #expect(RF.relativeAge(from: now.addingTimeInterval(-86_400), now: now) == "VOR 1 TAG")
        #expect(RF.relativeAge(from: now.addingTimeInterval(-3 * 86_400), now: now) == "VOR 3 TAGEN")
    }

    @Test("Countdown replaces the LIVE dot as a want runs out")
    func remaining() {
        let now = Date()
        #expect(RF.remaining(until: now.addingTimeInterval(2 * 86_400), now: now) == "2 TAGE")
        #expect(RF.remaining(until: now.addingTimeInterval(86_400 + 60), now: now) == "1 TAG")
        // Just under two days still reads "2 TAGE" — the case the USM card hits.
        #expect(RF.remaining(until: now.addingTimeInterval(2 * 86_400 - 90), now: now) == "2 TAGE")
        #expect(RF.remaining(until: now.addingTimeInterval(5 * 3600), now: now) == "5 STD")
        #expect(RF.remaining(until: now.addingTimeInterval(-60), now: now) == "ABGELAUFEN")
    }

    @Test("Chat stamps: time today, then Gestern, then a weekday")
    func chatStamps() {
        let now = Date()
        #expect(RF.chatStamp(now.addingTimeInterval(-60), now: now).contains(":"))
        var cal = Calendar(identifier: .gregorian)
        cal.locale = RF.locale
        let yesterdayNoon = cal.date(byAdding: .day, value: -1, to: now) ?? now
        #expect(RF.chatStamp(yesterdayNoon, now: now) == "Gestern")
    }

    @Test("Rating keeps a dot, never a localised comma")
    func rating() {
        #expect(RF.rating(4.9) == "4.9")
        #expect(RF.rating(4.0) == "4.0")
    }

    @Test("Member line")
    func memberSince() {
        #expect(RF.memberSince(MockSeed.me.memberSince) == "SEIT 2026")
    }
}

// MARK: - Models

@Suite("Model copy")
struct ModelTests {

    @Test("Constraint lines read exactly as the cards do")
    func constraintLines() {
        #expect(MockSeed.omegaWant.constraintLine == "bis CHF 2’000 · Zürich")
        #expect(MockSeed.omegaWant.detailConstraintLine == "bis CHF 2’000 · Original · Zürich")
        #expect(MockSeed.usmWant.offerCountLine == "1 Angebot")
        #expect(MockSeed.omegaWant.offerCountLine == "4 Angebote")
    }

    @Test("Over-budget offers swap the rating for the warning")
    func overBudget() {
        let want = MockSeed.omegaWant
        let furrer = MockSeed.offers.first { $0.id == "o-furrer" }!
        let marc = MockSeed.offers.first { $0.id == "o-marc" }!
        #expect(furrer.isOverBudget(for: want))
        #expect(!marc.isOverBudget(for: want))
        #expect(furrer.trustLine(for: want).hasPrefix("ÜBER BUDGET · "))
        #expect(marc.trustLine(for: want).hasPrefix("4.9 · 23 DEALS · "))
    }

    @Test("Chat context line is what distinguishes a refind thread")
    func contextLine() {
        let marc = MockSeed.threads.first { $0.id == "t-marc" }!
        #expect(marc.contextLine == "Omega Seamaster · CHF 1’720")
        let lena = MockSeed.threads.first { $0.id == "t-lena" }!
        #expect(lena.lastMessagePreview == "Du: Danke, ich überlege es mir.")
    }

    @Test("Draft validation follows the handoff's rules")
    func validation() {
        var draft = WantDraft()
        #expect(!draft.isValid)
        draft.title = "Om"
        draft.budgetMax = Money(chf: 500)
        #expect(!draft.titleIsValid)
        draft.title = "Omega Seamaster"
        #expect(draft.isValid)
        draft.budgetMax = Money(chf: 100_001)
        #expect(!draft.budgetIsValid)

        var offer = OfferDraft(wantID: "w-eames", price: Money(chf: 4_200))
        #expect(offer.isValid)
        #expect(offer.photosRecommended)
        offer.message = String(repeating: "a", count: 501)
        #expect(!offer.isValid)
    }
}

// MARK: - Repository

@Suite("MockRefindRepository")
struct RepositoryTests {

    @Test("Seeded lists match the mocks")
    func seeded() async throws {
        let repo = MockRefindRepository(latency: .zero)
        let mine = try await repo.myWants()
        #expect(mine.count == 3)
        #expect(mine.first?.title == "Omega Seamaster 166.062")
        // The expired Velo sinks to the bottom.
        #expect(mine.last?.status == .expired)

        let discover = try await repo.discoverWants(category: nil, query: "")
        #expect(discover.map(\.title) == ["Eames Lounge Chair, Nussbaum",
                                          "Leica M6, funktionierender Belichtungsmesser"])
        #expect(try await repo.savedWants().isEmpty)
    }

    @Test("Four offers on the Omega, cheapest first")
    func offerSort() async throws {
        let repo = MockRefindRepository(latency: .zero)
        let offers = try await repo.offers(forWant: "w-omega", sort: .priceAscending)
        #expect(offers.count == MockSeed.omegaWant.offerCount)
        #expect(offers.map(\.price) == offers.map(\.price).sorted())
        #expect(offers.first?.seller.displayName == "Marc B.")
    }

    @Test("Accepting an offer declines the others and opens a thread")
    func accept() async throws {
        let repo = MockRefindRepository(latency: .zero)
        let thread = try await repo.acceptOffer(id: "o-marc")
        #expect(thread.partner.displayName == "Marc B.")
        let after = try await repo.offers(forWant: "w-omega", sort: .newest)
        #expect(after.first { $0.id == "o-marc" }?.status == .accepted)
        #expect(after.filter { $0.id != "o-marc" }.allSatisfy { $0.status == .declined })
    }

    @Test("Posting a want puts it at the top of Home")
    func createWant() async throws {
        let repo = MockRefindRepository(latency: .zero)
        var draft = WantDraft()
        draft.title = "Braun SK 4"
        draft.category = .moebel
        draft.budgetMax = Money(chf: 1_200)
        let created = try await repo.createWant(draft)
        #expect(created.status == .live)
        let mine = try await repo.myWants()
        #expect(mine.first?.id == created.id)
    }

    @Test("Invalid drafts are refused with copy a screen can show")
    func rejectsInvalid() async throws {
        let repo = MockRefindRepository(latency: .zero)
        var draft = WantDraft()
        draft.title = "Om"
        draft.budgetMax = Money(chf: 100)
        await #expect(throws: RepositoryError.self) { try await repo.createWant(draft) }
    }

    @Test("Sending an offer creates the thread the flow promises")
    func sendOffer() async throws {
        let repo = MockRefindRepository(latency: .zero)
        let before = try await repo.threads().count
        _ = try await repo.sendOffer(
            OfferDraft(wantID: "w-eames", price: Money(chf: 4_200), message: "Nussbaum, Vitra 2009.")
        )
        #expect(try await repo.threads().count == before + 1)
    }

    @Test("Reading a thread clears its badge")
    func markRead() async throws {
        let repo = MockRefindRepository(latency: .zero)
        #expect(try await repo.threads().first { $0.id == "t-marc" }?.unreadCount == 2)
        try await repo.markRead(threadID: "t-marc")
        #expect(try await repo.threads().first { $0.id == "t-marc" }?.unreadCount == 0)
    }

    @Test("The failure knob drives every error state")
    func failureMode() async throws {
        let repo = MockRefindRepository(latency: .zero, failure: .offline)
        await #expect(throws: RepositoryError.offline) { try await repo.myWants() }
    }

    @Test("Mock escrow computes the numbers on screens 17 and 18")
    func escrow() async throws {
        let repo = MockRefindRepository(latency: .zero)
        let escrow = try await repo.startEscrow(dealID: "d-marc", method: .escrow)
        #expect(escrow.amount.formattedExact == "CHF 1’650.00")
        #expect(escrow.fee.formattedExact == "CHF 41.25")
        #expect(escrow.total.formattedExact == "CHF 1’691.25")
        #expect(escrow.stage == .paid)
        #expect(escrow.receiptNumber == "RF-2026-0114")

        let released = try await repo.releaseEscrow(id: escrow.id)
        #expect(released.stage == .released)
    }
}

// MARK: - Saving, escrow lifecycle, editing

@Suite("Saving and escrow")
struct SavedAndEscrowTests {

    @Test("Saving a want moves it into Gespeichert, unsaving takes it out")
    func saving() async throws {
        let repo = MockRefindRepository(latency: .zero)
        #expect(try await repo.savedWants().isEmpty)

        try await repo.setWantSaved(id: MockSeed.eamesWant.id, saved: true)
        let saved = try await repo.savedWants()
        #expect(saved.map(\.id) == [MockSeed.eamesWant.id])
        #expect(await repo.isSaved(wantID: MockSeed.eamesWant.id))

        try await repo.setWantSaved(id: MockSeed.eamesWant.id, saved: false)
        #expect(try await repo.savedWants().isEmpty)
    }

    @Test("Escrow walks Bezahlt → Übergabe → Freigabe, and only forward on demand")
    func escrowLifecycle() async throws {
        let repo = MockRefindRepository(latency: .zero)
        let escrow = try await repo.startEscrow(dealID: "d-marc", method: .escrow)
        #expect(escrow.stage == .paid)

        let handed = try await repo.confirmHandover(escrowID: escrow.id)
        #expect(handed.stage == .handover)

        let released = try await repo.releaseEscrow(id: escrow.id)
        #expect(released.stage == .released)

        // Reachable again from the thread, so the chat can reopen the status.
        let found = try await repo.escrow(forThread: "t-marc")
        #expect(found?.id == escrow.id)
        #expect(found?.stage == .released)
    }

    @Test("A thread with no escrow reports none")
    func noEscrow() async throws {
        let repo = MockRefindRepository(latency: .zero)
        #expect(try await repo.escrow(forThread: "t-lena") == nil)
    }

    @Test("Editing a want keeps its identity and offers")
    func editing() async throws {
        let repo = MockRefindRepository(latency: .zero)
        var draft = WantDraft()
        draft.title = "Omega Seamaster 166.062 – mit Papieren"
        draft.budgetMax = Money(chf: 2_400)
        draft.condition = .serviced
        draft.region = "Bern"

        let updated = try await repo.updateWant(id: MockSeed.omegaWant.id, draft: draft)
        #expect(updated.id == MockSeed.omegaWant.id)
        #expect(updated.budgetMax == Money(chf: 2_400))
        #expect(updated.condition == .serviced)
        #expect(updated.offerCount == MockSeed.omegaWant.offerCount)
        #expect(try await repo.offers(forWant: updated.id, sort: .newest).count == 4)
    }

    @Test("Editing refuses the same invalid input as posting")
    func editingValidates() async throws {
        let repo = MockRefindRepository(latency: .zero)
        var draft = WantDraft()
        draft.title = "Om"
        draft.budgetMax = Money(chf: 100)
        await #expect(throws: RepositoryError.self) {
            try await repo.updateWant(id: MockSeed.omegaWant.id, draft: draft)
        }
    }

    @Test("A rating is recorded against the deal")
    func rating() async throws {
        let repo = MockRefindRepository(latency: .zero)
        try await repo.rate(dealID: "d-marc", stars: 5)
    }
}
