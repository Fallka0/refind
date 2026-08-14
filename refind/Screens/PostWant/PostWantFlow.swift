//
//  PostWantFlow.swift
//  refind
//
//  The modal flow: 04 → 05 → review → 06, on its own navigation stack.
//

import SwiftUI

struct PostWantFlow: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    /// Called with the new want once it is live, so Home can refresh.
    var onFinished: (Want) -> Void = { _ in }

    @State private var store: PostWantStore?
    @State private var path: [Step] = []

    private enum Step: Hashable {
        case details, review, live
    }

    var body: some View {
        Group {
            if let store {
                NavigationStack(path: $path) {
                    PostTitleStep(store: store,
                                  onCancel: { dismiss() },
                                  onNext: { path.append(.details) })
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
            let city = environment.currentUser?.city ?? MockSeed.me.city
            store = PostWantStore(repository: environment.repository, city: city)
        }
    }

    @ViewBuilder
    private func destination(_ step: Step, store: PostWantStore) -> some View {
        switch step {
        case .details:
            PostDetailsStep(store: store,
                            onBack: { path.removeLast() },
                            onNext: { path.append(.review) })
        case .review:
            PostReviewStep(store: store,
                           onBack: { path.removeLast() },
                           onSubmit: { Task { await submit(store) } })
        case .live:
            if let want = store.createdWant {
                WantLiveScreen(want: want) {
                    onFinished(want)
                    dismiss()
                }
            }
        }
    }

    private func submit(_ store: PostWantStore) async {
        await store.submit()
        guard store.createdWant != nil else { return }   // error stays on the review step
        path.append(.live)
    }
}
