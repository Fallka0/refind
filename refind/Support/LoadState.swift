//
//  LoadState.swift
//  refind
//
//  Every list in the product owes four states: loading (skeleton cards, no
//  spinner), empty (Fin + one line + the relevant CTA), error (inline line +
//  "Nochmal versuchen"), and content. Routing them through one enum is what
//  keeps that a rule instead of a good intention.
//

import Foundation

enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

extension LoadState where Value: Collection {
    /// Loaded but with nothing in it — the empty state, distinct from still loading.
    var isEmpty: Bool { value?.isEmpty ?? false }
}
