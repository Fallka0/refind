//
//  Offer.swift
//  refind
//

import Foundation

enum OfferSort: String, CaseIterable, Identifiable, Hashable, Sendable {
    case priceAscending, priceDescending, newest

    var id: String { rawValue }

    /// The sort control on screen 07 reads "Preis ↑".
    var displayName: String {
        switch self {
        case .priceAscending:  return "Preis ↑"
        case .priceDescending: return "Preis ↓"
        case .newest:          return "Neuste"
        }
    }
}

struct Offer: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case sent, accepted, declined, withdrawn
    }

    let id: String
    let wantID: String
    let seller: User
    let price: Money
    let message: String
    let photos: [PhotoRef]
    let createdAt: Date
    let status: Status

    func isOverBudget(for want: Want) -> Bool { price > want.budgetMax }

    /// "4.9 · 23 DEALS · VOR 12 MIN", or "ÜBER BUDGET · VOR 3 STD" when the
    /// price exceeds the want's budget — the design swaps the rating for the warning.
    func trustLine(for want: Want, now: Date = .now) -> String {
        let age = RF.relativeAge(from: createdAt, now: now)
        return isOverBudget(for: want)
            ? "ÜBER BUDGET · \(age)"
            : "\(seller.trustLine) · \(age)"
    }
}

/// No image assets ship with the app. A photo is a stable seed that
/// `RFMockPhoto` turns into a deterministic placeholder, so the same offer
/// always draws the same picture.
struct PhotoRef: Identifiable, Hashable, Sendable {
    let id: String
    /// Optional real URL — unused by the mock repository, ready for the live one.
    let url: URL?

    init(id: String, url: URL? = nil) {
        self.id = id
        self.url = url
    }
}
