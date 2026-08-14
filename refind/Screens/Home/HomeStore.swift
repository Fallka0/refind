//
//  HomeStore.swift
//  refind
//

import SwiftUI

@MainActor
@Observable
final class HomeStore {

    enum Segment: String, CaseIterable, Identifiable, Hashable {
        case mine, saved

        var id: String { rawValue }
        var title: String {
            switch self {
            case .mine:  return String(localized: "Meine Gesuche")
            case .saved: return String(localized: "Gespeichert")
            }
        }
    }

    var segment: Segment = .mine
    var mine: LoadState<[Want]> = .idle
    var saved: LoadState<[Want]> = .idle

    private let repository: any RefindRepository

    init(repository: any RefindRepository) {
        self.repository = repository
    }

    var current: LoadState<[Want]> {
        segment == .mine ? mine : saved
    }

    func load(_ segment: Segment, force: Bool = false) async {
        if !force, case .loaded = state(for: segment) { return }
        setState(.loading, for: segment)
        do {
            let wants = segment == .mine
                ? try await repository.myWants()
                : try await repository.savedWants()
            setState(.loaded(wants), for: segment)
        } catch {
            setState(.failed(message(for: error)), for: segment)
        }
    }

    func unsave(_ want: Want) async {
        try? await repository.setWantSaved(id: want.id, saved: false)
        await load(.saved, force: true)
    }

    /// Tapping an expired card puts it back on the wall.
    func republish(_ want: Want) async {
        guard (try? await repository.republishWant(id: want.id)) != nil else { return }
        await load(.mine, force: true)
    }

    // MARK: Helpers

    private func state(for segment: Segment) -> LoadState<[Want]> {
        segment == .mine ? mine : saved
    }

    private func setState(_ state: LoadState<[Want]>, for segment: Segment) {
        if segment == .mine { mine = state } else { saved = state }
    }

    private func message(for error: Error) -> String {
        (error as? RepositoryError)?.inlineMessage ?? RepositoryError.server.inlineMessage
    }
}
