//
//  DiscoverStore.swift
//  refind
//

import SwiftUI

@MainActor
@Observable
final class DiscoverStore {

    var query = ""
    var category: Category?
    var wants: LoadState<[Want]> = .idle
    var owners: [String: User] = [:]
    var offerTarget: Want?
    var toast: String?
    var savedIDs: Set<String> = []

    private let repository: any RefindRepository
    private var searchTask: Task<Void, Never>?

    init(repository: any RefindRepository) {
        self.repository = repository
    }

    func load() async {
        wants = .loading
        do {
            let results = try await repository.discoverWants(category: category, query: query)
            wants = .loaded(results)
            // People come from the seed today; a live repository would return
            // them alongside the wants.
            owners = Dictionary(
                uniqueKeysWithValues: MockSeed.people.map { ($0.id, $0) }
            )
        } catch {
            wants = .failed((error as? RepositoryError)?.inlineMessage
                            ?? RepositoryError.server.inlineMessage)
        }
    }

    /// Debounced so typing does not fire a query per keystroke.
    func queryChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    func select(_ category: Category?) async {
        self.category = category
        await load()
    }

    func toggleSaved(_ want: Want) async {
        let willSave = !savedIDs.contains(want.id)
        try? await repository.setWantSaved(id: want.id, saved: willSave)
        if willSave { savedIDs.insert(want.id) } else { savedIDs.remove(want.id) }
        toast = willSave ? "Gespeichert" : "Entfernt"
    }

    func refreshSaved() async {
        let saved = (try? await repository.savedWants()) ?? []
        savedIDs = Set(saved.map(\.id))
    }

    func owner(of want: Want) -> User {
        owners[want.ownerID] ?? MockSeed.nina
    }
}
