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
    case invalidInput(String)
    case server

    var errorDescription: String? {
        switch self {
        case .offline:              return "Keine Verbindung."
        case .notFound:             return "Das gibt es nicht mehr."
        case .invalidInput(let m):  return m
        case .server:               return "Das hat nicht geklappt."
        }
    }

    /// What a list shows inline when it cannot load.
    var inlineMessage: String { errorDescription ?? "Das hat nicht geklappt." }
}
