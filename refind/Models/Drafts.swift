//
//  Drafts.swift
//  refind
//
//  What the composing screens hand back to the repository, plus the validation
//  rules from the handoff. Validation lives here so the flow screens and the
//  repository agree on one definition.
//

import Foundation

struct WantDraft: Hashable, Sendable {
    var title: String = ""
    var category: Category = .uhren
    var budgetMax: Money = Money(chf: 0)
    var condition: Condition = .original
    var region: String = "Zürich"
    var radiusKm: Int = 30
    var durationDays: Int = 14

    /// Title ≥ 3 chars; budget > 0 and ≤ 100'000.
    static let maxBudget = Money(chf: 100_000)

    var titleIsValid: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 }
    var budgetIsValid: Bool { budgetMax > .zero && budgetMax <= Self.maxBudget }
    var isValid: Bool { titleIsValid && budgetIsValid }

    /// "Zürich + 30 km"
    var regionLine: String { "\(region) + \(radiusKm) km" }
    /// "14 Tage sichtbar"
    var durationLine: String { "\(durationDays) Tage sichtbar" }
}

struct OfferDraft: Hashable, Sendable {
    var wantID: String
    var price: Money = .zero
    var message: String = ""
    var photos: [PhotoRef] = []

    /// Message ≤ 500 chars; at least one photo is recommended, never required.
    static let maxMessageLength = 500
    static let maxPhotos = 6

    var priceIsValid: Bool { price > .zero }
    var messageIsValid: Bool { message.count <= Self.maxMessageLength }
    var isValid: Bool { priceIsValid && messageIsValid }

    /// Over-budget offers warn but never block — the design renders them as ÜBER BUDGET.
    func exceedsBudget(of want: Want) -> Bool { price > want.budgetMax }
    var photosRecommended: Bool { photos.isEmpty }
}

struct MessageDraft: Hashable, Sendable {
    var threadID: String
    var kind: Message.Kind = .text
    var body: String = ""
}

struct DealDraft: Hashable, Sendable {
    var threadID: String
    var finalPrice: Money
    var handoverAt: Date
    var handoverPlace: String
}
