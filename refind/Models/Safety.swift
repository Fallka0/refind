//
//  Safety.swift
//  refind
//
//  Reporting, blocking, disputes and identity verification. None of these are
//  drawn in the handoff — they are listed there as needing a decision — so the
//  shapes here are proposals built in the existing language.
//

import Foundation

enum ReportSubject: Hashable, Sendable {
    case user(String)
    case want(String)
    case offer(String)
    case message(String)

    var wireType: String {
        switch self {
        // Wire values, never shown — these must not be localised.
        case .user:    return "user"
        case .want:    return "want"
        case .offer:   return "offer"
        case .message: return "message"
        }
    }

    var id: String {
        switch self {
        case .user(let id), .want(let id), .offer(let id), .message(let id): return id
        }
    }
}

enum ReportReason: String, CaseIterable, Identifiable, Hashable, Sendable {
    case scam, counterfeit, prohibited, harassment, spam, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scam:        return String(localized: "Betrugsverdacht")
        case .counterfeit: return String(localized: "Fälschung")
        case .prohibited:  return String(localized: "Verbotener Artikel")
        case .harassment:  return String(localized: "Belästigung")
        case .spam:        return String(localized: "Spam")
        case .other:       return String(localized: "Etwas anderes")
        }
    }
}

enum DisputeReason: String, CaseIterable, Identifiable, Hashable, Sendable {
    case notAsDescribed, notHandedOver, damaged, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notAsDescribed: return String(localized: "Nicht wie beschrieben")
        case .notHandedOver:  return String(localized: "Keine Übergabe")
        case .damaged:        return String(localized: "Beschädigt")
        case .other:          return String(localized: "Etwas anderes")
        }
    }
}

enum VerificationStatus: String, Hashable, Sendable {
    case unverified, pending, verified, rejected

    /// The value shown on the Profil row.
    var displayName: String {
        switch self {
        case .unverified: return String(localized: "offen")
        case .pending:    return String(localized: "in Prüfung")
        case .verified:   return String(localized: "bestätigt")
        case .rejected:   return String(localized: "abgelehnt")
        }
    }

    /// Only the open state earns the accent colour.
    var isAttention: Bool { self == .unverified || self == .rejected }
}
