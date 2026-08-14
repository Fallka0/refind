//
//  PostReviewStep.swift
//  refind
//
//  Screen 05b · review (step 3 of 3). Not drawn in the mocks — the handoff says
//  "reuse card + primary", so this is exactly that, plus the category chips:
//  the category is guessed from the title and this is the only place the guess
//  can be corrected before the want goes live.
//

import SwiftUI

struct PostReviewStep: View {
    @Bindable var store: PostWantStore
    let onBack: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RFFlowHeader(leadingTitle: "Zurück", step: 3, onLeading: onBack)

                    Text("Passt das so?")
                        .font(RF.display(40))
                        .foregroundStyle(RF.Palette.ink)
                        .padding(.top, 26)

                    RFCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dein Gesuch").rfLabel(10)
                            Text(store.draft.title)
                                .font(RF.display(24))
                                .foregroundStyle(RF.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(store.summaryLine)
                                .font(RF.num(12, weight: .medium))
                                .foregroundStyle(RF.Palette.inkMid)
                            Text(store.draft.condition.displayName)
                                .font(RF.ui(13))
                                .foregroundStyle(RF.Palette.muted)
                        }
                    }
                    .padding(.top, 30)

                    RFFieldGroup(title: "Kategorie") {
                        FlowRow(spacing: 8) {
                            ForEach(Category.allCases) { category in
                                Button {
                                    store.draft.category = category
                                } label: {
                                    RFChip(title: category.displayName,
                                           selected: store.draft.category == category)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 34)

                    if let errorMessage = store.errorMessage {
                        Text(errorMessage.uppercased())
                            .rfLabel(11, color: RF.Palette.offer)
                            .padding(.top, 22)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.top, RF.Metric.topInsetFlow)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button(store.isSubmitting ? "Wird aufgehängt …" : "Gesuch aufhängen", action: onSubmit)
                .buttonStyle(RFButtonStyle(kind: store.isSubmitting ? .disabled : .primary))
                .disabled(store.isSubmitting)
                .accessibilityIdentifier("post.submit")
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.bottom, 12)
        }
    }
}

#Preview("05b Review") {
    let store = PostWantStore(repository: MockRefindRepository.instant, city: "Zürich")
    store.draft.title = "Omega Seamaster 166.062"
    return PostReviewStep(store: store, onBack: {}, onSubmit: {})
}
