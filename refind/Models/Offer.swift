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
        case .priceAscending:  return String(localized: "Preis ↑")
        case .priceDescending: return String(localized: "Preis ↓")
        case .newest:          return String(localized: "Neuste")
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

/// A photo is either something the user picked (carried as data until there is
/// a backend to upload it to), a remote URL, or neither — in which case
/// `RFPhoto` draws a deterministic stand-in from the id, so seeded content
/// still looks like content.
struct PhotoRef: Identifiable, Hashable, Sendable {
    let id: String
    /// Ready for the live repository.
    let url: URL?
    /// A locally picked image. Not persisted anywhere yet.
    let localData: Data?

    init(id: String, url: URL? = nil, localData: Data? = nil) {
        self.id = id
        self.url = url
        self.localData = localData
    }
}
