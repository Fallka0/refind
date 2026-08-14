//
//  Want.swift
//  refind
//
//  A Gesuch: what someone is looking for.
//

import Foundation

enum Category: String, CaseIterable, Identifiable, Hashable, Sendable {
    case uhren, moebel, velo, vinyl, kameras, werkzeug

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uhren:    return "Uhren"
        case .moebel:   return "Möbel"
        case .velo:     return "Velo"
        case .vinyl:    return "Vinyl"
        case .kameras:  return "Kameras"
        case .werkzeug: return "Werkzeug"
        }
    }
}

enum Condition: String, CaseIterable, Identifiable, Hashable, Sendable {
    case original, serviced, any

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .serviced: return "Serviciert"
        case .any:      return "Egal"
        }
    }
}

struct Want: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case live, paused, expired, fulfilled
    }

    let id: String
    let ownerID: String
    let title: String
    let category: Category
    let budgetMax: Money
    let condition: Condition
    let region: String
    let radiusKm: Int
    let itemDescription: String?
    let createdAt: Date
    let expiresAt: Date
    let status: Status
    let offerCount: Int
    let unreadOfferCount: Int

    var isLive: Bool { status == .live }
    var isExpired: Bool { status == .expired }

    /// "bis CHF 2'000 · Zürich" — the constraint line on a card.
    var constraintLine: String {
        "bis \(budgetMax.formatted) · \(region)"
    }

    /// "bis CHF 2'000 · Original · Zürich" — the longer form on the detail header.
    var detailConstraintLine: String {
        "bis \(budgetMax.formatted) · \(condition.displayName) · \(region)"
    }

    /// "4 Angebote" / "1 Angebot".
    var offerCountLine: String {
        offerCount == 1 ? "1 Angebot" : "\(offerCount) Angebote"
    }
}
