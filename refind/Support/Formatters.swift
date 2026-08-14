//
//  Formatters.swift
//  refind
//
//  Every date, age and countdown string in the product comes from here, in
//  de_CH. Extends RF rather than editing DesignSystem.swift, which stays
//  exactly as it shipped in the handoff.
//

import Foundation

extension RF {

    static let locale = Locale(identifier: "de_CH")

    /// "4.9" — one decimal, never localised to a comma (the mocks show a dot).
    static func rating(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// "VOR 12 MIN" / "VOR 1 STD" / "VOR 3 TAGEN" — the age stamp on offers and feed cards.
    /// Returned in caps because every use site is a label.
    static func relativeAge(from date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "GERADE EBEN" }
        if minutes < 60 { return "VOR \(minutes) MIN" }
        let hours = minutes / 60
        if hours < 24 { return "VOR \(hours) STD" }
        let days = hours / 24
        return days == 1 ? "VOR 1 TAG" : "VOR \(days) TAGEN"
    }

    /// "2 TAGE" — the countdown that replaces the LIVE dot as a want runs out.
    static func remaining(until date: Date, now: Date = .now) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "ABGELAUFEN" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return hours <= 1 ? "1 STD" : "\(hours) STD" }
        let days = hours / 24
        return days == 1 ? "1 TAG" : "\(days) TAGE"
    }

    /// "12:04" today, "Gestern", "Mo" this week, "14.08." older — the chat list stamp.
    static func chatStamp(_ date: Date, now: Date = .now) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        if cal.isDate(date, inSameDayAs: now) {
            let f = DateFormatter()
            f.locale = locale
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now),
           cal.isDate(date, inSameDayAs: yesterday) {
            return "Gestern"
        }
        let days = cal.dateComponents([.day], from: date, to: now).day ?? 0
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = days < 7 ? "EE" : "dd.MM."
        return f.string(from: date)
    }

    /// "SA, 14:00" — the handover stamp on the deal card, already in caps.
    static func handoverStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "EE, HH:mm"
        return f.string(from: date).uppercased()
    }

    /// "heute, 12:41" — the receipt line on the escrow screen.
    static func receiptStamp(_ date: Date, now: Date = .now) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "HH:mm"
        let time = f.string(from: date)
        if cal.isDate(date, inSameDayAs: now) { return "heute, \(time)" }
        let d = DateFormatter()
        d.locale = locale
        d.dateFormat = "dd.MM."
        return "\(d.string(from: date)) \(time)"
    }

    /// "SEIT 2026" — the profile meta line.
    static func memberSince(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "yyyy"
        return "SEIT \(f.string(from: date))"
    }
}
