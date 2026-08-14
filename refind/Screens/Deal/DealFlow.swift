//
//  DealFlow.swift
//  refind
//
//  The "Deal" button in a negotiation opens this.
//
//  The handoff numbers the screens 12 and 14–18 but never says how they join
//  up. The reading that uses each screen exactly as drawn:
//
//    14 choose payment
//      ├─ Bar bei Übergabe  → 12 "Gefunden."      (refind is not involved)
//      └─ Treuhand / Karte  → 16 → 17 → 18 "Geld ist sicher."
//
//  So the two celebration screens are not alternatives to each other by
//  accident — they are the endings of the two payment paths.
//

import SwiftUI

struct DealFlow: View {
    let thread: ChatThread
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var store: DealStore?
    @State private var path: [Step] = []

    private enum Step: Hashable {
        case card, confirm, escrowDone, dealDone
    }

    var body: some View {
        Group {
            if let store {
                NavigationStack(path: $path) {
                    PaymentMethodStep(store: store,
                                      onBack: { dismiss() },
                                      onNext: { advanceFromMethod(store) })
                        .navigationBarBackButtonHidden()
                        .navigationDestination(for: Step.self) { step in
                            destination(step, store: store)
                                .navigationBarBackButtonHidden()
                        }
                }
            } else {
                RF.Palette.paper.ignoresSafeArea()
            }
        }
        .task {
            guard store == nil else { return }
            let store = DealStore(thread: thread, repository: environment.repository)
            self.store = store
            await store.prepareDeal()
            // Money already in escrow: reopen the status rather than starting a
            // second payment for the same deal.
            await store.loadExistingEscrow()
            if store.escrow != nil { path.append(.escrowDone) }
        }
    }

    @ViewBuilder
    private func destination(_ step: Step, store: DealStore) -> some View {
        switch step {
        case .card:
            CardStep(store: store,
                     onBack: { path.removeLast() },
                     onNext: { Task { await beginEscrow(store) } })
        case .confirm:
            ConfirmPayStep(store: store,
                           onBack: { path.removeLast() },
                           onPaid: { path.append(.escrowDone) })
        case .escrowDone:
            EscrowActiveScreen(store: store, onBackToChat: { dismiss() })
        case .dealDone:
            DealConfirmedScreen(store: store, onDone: { dismiss() })
        }
    }

    private func advanceFromMethod(_ store: DealStore) {
        // Cash never touches the payment sheet — refind is not in the middle.
        path.append(store.method == .cash ? .dealDone : .card)
    }

    private func beginEscrow(_ store: DealStore) async {
        guard await store.startEscrow() else { return }
        path.append(.confirm)
    }
}
