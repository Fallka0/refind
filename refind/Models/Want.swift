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

    /// The post flow never asks for a category — neither drawn step has the
    /// field — but a want carries one and Home prints it on every card. So it
    /// is guessed from the title here, and the (undrawn) review step shows the
    /// guess as chips so it can be corrected before the want goes live.
    static func inferred(from title: String) -> Category? {
        let text = title.lowercased()
        let table: [(Category, [String])] = [
            (.uhren, ["omega", "seamaster", "speedmaster", "rolex", "tissot", "uhr",
                      "constellation", "chronograph", "longines", "iwc"]),
            (.kameras, ["leica", "kamera", "nikon", "canon", "hasselblad", "objektiv",
                        "rolleiflex", "contax"]),
            (.moebel, ["usm", "eames", "vitra", "stuhl", "tisch", "sideboard", "sofa",
                       "lampe", "regal", "sessel", "kommode", "braun"]),
            (.velo, ["velo", "rennvelo", "fahrrad", "bike", "mtb", "rahmen"]),
            (.vinyl, ["vinyl", "schallplatte", "platte", "lp", "album"]),
            (.werkzeug, ["werkzeug", "bohrmaschine", "säge", "festool", "hobel", "fräse"])
        ]
        for (category, keywords) in table where keywords.contains(where: text.contains) {
            return category
        }
        return nil
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
