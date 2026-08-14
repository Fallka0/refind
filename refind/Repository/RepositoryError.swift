//
//  RepositoryError.swift
//  refind
//
//  Error copy is product copy: du-form, one short line, always paired with
//  "Nochmal versuchen" at the call site.
//

import Foundation

enum RepositoryError: LocalizedError, Hashable, Sendable {
    case offline
    case notFound
    case unauthorized
    /// 429 with the server's Retry-After, in seconds.
    case rateLimited(retryAfter: Double)
    case invalidInput(String)
    case server

    var errorDescription: String? {
        switch self {
        case .offline:              return String(localized: "Keine Verbindung.")
        case .notFound:             return String(localized: "Das gibt es nicht mehr.")
        case .unauthorized:         return String(localized: "Bitte melde dich neu an.")
        case .rateLimited:          return String(localized: "Zu viele Versuche. Probier es später nochmal.")
        case .invalidInput(let m):  return m
        case .server:               return String(localized: "Das hat nicht geklappt.")
        }
    }

    /// What a list shows inline when it cannot load.
    var inlineMessage: String { errorDescription ?? "Das hat nicht geklappt." }
}
