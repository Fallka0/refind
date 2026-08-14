//
//  Money.swift
//  refind
//
//  Amounts are stored as minor units (Rappen) and only ever become strings
//  through here, so no screen formats a price by hand.
//

import Foundation

struct Money: Hashable, Sendable, Comparable {
    /// Rappen. CHF 1'650 == 165_000.
    let minorUnits: Int

    init(minorUnits: Int) { self.minorUnits = minorUnits }
    init(chf: Int) { self.minorUnits = chf * 100 }

    var decimal: Decimal { Decimal(minorUnits) / 100 }

    /// "CHF 1'650" — the default across the app; the designs round everywhere
    /// except the escrow totals.
    var formatted: String { RF.price(decimal) }

    /// "CHF 1'691.25" — escrow fee, total, receipt lines (screens 17 / 18).
    var formattedExact: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = "\u{2019}"
        let value = f.string(from: decimal as NSDecimalNumber) ?? "0.00"
        return "CHF \(value)"
    }

    /// Digits only — for the underline fields that print "CHF" as a separate label.
    var digitsOnly: String { RF.price(decimal, showCurrency: false) }

    static func < (lhs: Money, rhs: Money) -> Bool { lhs.minorUnits < rhs.minorUnits }

    static func + (lhs: Money, rhs: Money) -> Money {
        Money(minorUnits: lhs.minorUnits + rhs.minorUnits)
    }

    /// Rounds to the nearest Rappen — the 2.5% escrow fee lands on exact values
    /// in the designs (CHF 1'650 → CHF 41.25), but the rate is not integral in general.
    func percentage(_ rate: Decimal) -> Money {
        let raw = (Decimal(minorUnits) * rate) as NSDecimalNumber
        return Money(minorUnits: Int(raw.doubleValue.rounded()))
    }

    static let zero = Money(minorUnits: 0)
}
