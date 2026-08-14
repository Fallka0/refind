//
//  Deal.swift
//  refind
//
//  Closing a deal, and the mock escrow that can follow it.
//  Nothing here talks to a payment SDK — screens 14–18 simulate the flow with
//  local state and fake delays. No card is ever charged.
//

import Foundation

struct Deal: Identifiable, Hashable, Sendable {
    let id: String
    let offerID: String
    let threadID: String
    let wantTitle: String
    let partner: User
    let finalPrice: Money
    let handoverAt: Date
    let handoverPlace: String
    let ratedByBuyer: Bool
    let ratedBySeller: Bool

    /// "SA, 14:00 · ZÜRICH HB" — the meta row on the confirmation card.
    var handoverLine: String {
        "\(RF.handoverStamp(handoverAt)) · \(handoverPlace.uppercased())"
    }
}

enum PaymentMethod: String, CaseIterable, Identifiable, Hashable, Sendable {
    case escrow, card, cash

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .escrow: return String(localized: "refind Treuhand")
        case .card:   return String(localized: "Direkt per Karte")
        case .cash:   return String(localized: "Bar bei Übergabe")
        }
    }

    var explanation: String {
        switch self {
        case .escrow: return String(localized: "Wir halten das Geld, bis du die Ware in der Hand hast. Der Verkäufer sieht, dass bezahlt ist.")
        case .card:   return String(localized: "Sofort an den Verkäufer, keine Absicherung")
        case .cash:   return String(localized: "refind ist nicht beteiligt")
        }
    }

    var isRecommended: Bool { self == .escrow }
    /// Only the escrow path opens the mock payment flow.
    var chargesThroughRefind: Bool { self == .escrow || self == .card }
}

struct Escrow: Identifiable, Hashable, Sendable {
    /// Bezahlt → Übergabe → Freigabe, the three-segment tracker on screen 18.
    enum Stage: Int, Hashable, Sendable, CaseIterable {
        case paid = 0, handover = 1, released = 2

        var displayName: String {
            switch self {
            case .paid:     return String(localized: "Bezahlt")
            case .handover: return String(localized: "Übergabe")
            case .released: return String(localized: "Freigabe")
            }
        }
    }

    static let feeRate: Decimal = 0.025

    let id: String
    let dealID: String
    let method: PaymentMethod
    let amount: Money
    let fee: Money
    let receiptNumber: String
    let paidAt: Date
    let stage: Stage

    var total: Money { amount + fee }

    /// "Gebühr 2.5 %"
    static let feeLabel = "Gebühr 2.5 %"
    static let feeRowLabel = "Treuhandgebühr 2.5 %"

    static func fee(on amount: Money) -> Money { amount.percentage(feeRate) }
}
