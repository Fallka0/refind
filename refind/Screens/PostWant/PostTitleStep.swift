//
//  PostTitleStep.swift
//  refind
//
//  Screen 04 · Gesuch aufhängen · Titel (step 1 of 3)
//

import SwiftUI

struct PostTitleStep: View {
    @Bindable var store: PostWantStore
    let onCancel: () -> Void
    let onNext: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                RFFlowHeader(leadingTitle: "Abbrechen", step: 1, onLeading: onCancel)

                Text("Was suchst du?")
                    .font(RF.display(40))
                    .foregroundStyle(RF.Palette.ink)
                    .padding(.top, 26)

                RFUnderlineField(placeholder: "", text: $store.draft.title)
                    .focused($focused)
                    .submitLabel(.next)
                    .onSubmit { if store.draft.titleIsValid { advance() } }
                    .padding(.top, 26)
                    .onChange(of: store.draft.title) { _, new in
                        store.suggestionsChanged(for: new)
                    }

                Text("Marke + Modell + Referenz findet mehr")
                    .rfLabel(10, tracking: 0.6)
                    .padding(.top, 10)

                if !store.suggestions.isEmpty {
                    suggestionList.padding(.top, 26)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, RF.Metric.topInsetFlow)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Weiter", action: advance)
                .buttonStyle(RFButtonStyle(kind: store.draft.titleIsValid ? .primary : .disabled))
                .disabled(!store.draft.titleIsValid)
                // Each step's primary carries the same label, and the stack
                // keeps earlier steps alive — identifiers keep them apart.
                .accessibilityIdentifier("post.title.next")
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.bottom, 12)
        }
        .onAppear { focused = true }
    }

    private var suggestionList: some View {
        RFFieldGroup(title: "Vorschläge", spacing: 10) {
            VStack(spacing: 0) {
                ForEach(Array(store.suggestions.enumerated()), id: \.element) { index, suggestion in
                    Button {
                        store.apply(suggestion: suggestion)
                    } label: {
                        HStack {
                            Text(suggestion)
                                .font(RF.ui(15))
                                .foregroundStyle(RF.Palette.ink)
                            Spacer()
                        }
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        if index < store.suggestions.count - 1 {
                            Rectangle()
                                .fill(RF.Palette.line)
                                .frame(height: RF.Metric.hairline)
                        }
                    }
                }
            }
        }
    }

    private func advance() {
        guard store.draft.titleIsValid else { return }
        store.inferCategory()
        focused = false
        onNext()
    }
}

#Preview("04 Titel") {
    PostTitleStep(store: PostWantStore(repository: MockRefindRepository.instant, city: "Zürich"),
                  onCancel: {}, onNext: {})
}
