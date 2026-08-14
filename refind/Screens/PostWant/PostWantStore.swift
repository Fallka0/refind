//
//  PostWantStore.swift
//  refind
//
//  Owns the draft across the three steps of the modal flow.
//

import SwiftUI

struct RadiusOption: Identifiable, Hashable {
    let km: Int
    var id: Int { km }
    static let all = [10, 20, 30, 50, 100].map(RadiusOption.init)
}

struct DurationOption: Identifiable, Hashable {
    let days: Int
    var id: Int { days }
    static let all = [7, 14, 30].map(DurationOption.init)
}

struct RegionOption: Identifiable, Hashable {
    let name: String
    var id: String { name }
    static let all = ["Zürich", "Bern", "Basel", "Luzern", "Winterthur", "St. Gallen"]
        .map(RegionOption.init)
}

@MainActor
@Observable
final class PostWantStore {

    var draft = WantDraft()
    /// The budget track's upper end; grows when the knob hits it.
    var sliderCeiling = 3_200
    var suggestions: [String] = []
    var isSubmitting = false
    var errorMessage: String?
    var createdWant: Want?

    private let repository: any RefindRepository
    private var suggestionTask: Task<Void, Never>?

    init(repository: any RefindRepository, city: String) {
        self.repository = repository
        draft.region = city
        draft.budgetMax = Money(chf: 2_000)
    }

    /// Debounced so a fast typist does not fire a lookup per keystroke.
    func suggestionsChanged(for prefix: String) {
        suggestionTask?.cancel()
        suggestionTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let results = (try? await repository.titleSuggestions(prefix: prefix)) ?? []
            guard !Task.isCancelled else { return }
            suggestions = results
        }
    }

    func apply(suggestion: String) {
        draft.title = suggestion
        suggestions = []
        inferCategory()
    }

    func inferCategory() {
        if let inferred = Category.inferred(from: draft.title) {
            draft.category = inferred
        }
    }

    var summaryLine: String {
        "bis \(draft.budgetMax.formatted) · \(draft.region) · \(draft.durationDays) Tage"
    }

    func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            createdWant = try await repository.createWant(draft)
        } catch {
            errorMessage = (error as? RepositoryError)?.inlineMessage
                ?? RepositoryError.server.inlineMessage
        }
        isSubmitting = false
    }
}
