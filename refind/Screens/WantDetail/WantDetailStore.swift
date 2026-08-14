//
//  WantDetailStore.swift
//  refind
//

import SwiftUI

@MainActor
@Observable
final class WantDetailStore {

    let wantID: String
    var want: LoadState<Want> = .idle
    var offers: LoadState<[Offer]> = .idle
    var sort: OfferSort = .priceAscending

    /// Set once an offer is accepted, so the screen can move on to the thread.
    var acceptedThread: ChatThread?
    var pendingAccept: Offer?
    var isPaused = false

    private let repository: any RefindRepository

    init(wantID: String, repository: any RefindRepository) {
        self.wantID = wantID
        self.repository = repository
    }

    func load(force: Bool = false) async {
        if !force, case .loaded = want {} else {
            want = .loading
            do {
                let loaded = try await repository.want(id: wantID)
                want = .loaded(loaded)
                isPaused = loaded.status == .paused
            } catch {
                want = .failed(message(for: error))
            }
        }
        await loadOffers()
    }

    func loadOffers() async {
        offers = .loading
        do {
            offers = .loaded(try await repository.offers(forWant: wantID, sort: sort))
        } catch {
            offers = .failed(message(for: error))
        }
    }

    func cycleSort() async {
        sort = switch sort {
        case .priceAscending:  .priceDescending
        case .priceDescending: .newest
        case .newest:          .priceAscending
        }
        await loadOffers()
    }

    func confirmAccept() async {
        guard let offer = pendingAccept else { return }
        pendingAccept = nil
        acceptedThread = try? await repository.acceptOffer(id: offer.id)
        await load(force: true)
    }

    func togglePaused() async {
        guard let current = want.value else { return }
        let updated = try? await repository.setWantPaused(id: current.id,
                                                          paused: current.status != .paused)
        if let updated {
            want = .loaded(updated)
            isPaused = updated.status == .paused
        }
    }

    private func message(for error: Error) -> String {
        (error as? RepositoryError)?.inlineMessage ?? RepositoryError.server.inlineMessage
    }
}
