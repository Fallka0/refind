//
//  PostDetailsStep.swift
//  refind
//
//  Screen 05 · Gesuch aufhängen · Details (step 2 of 3)
//

import SwiftUI

struct PostDetailsStep: View {
    @Bindable var store: PostWantStore
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var editingRegion = false
    @State private var editingRadius = false
    @State private var editingDuration = false

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RFFlowHeader(leadingTitle: "Zurück", step: 2, onLeading: onBack)

                    Text("Wie viel, welcher Zustand?")
                        .font(RF.display(40))
                        .foregroundStyle(RF.Palette.ink)
                        .padding(.top, 26)

                    RFFieldGroup(title: "Budget", spacing: 10) {
                        RFBudgetSlider(value: $store.draft.budgetMax,
                                       ceiling: $store.sliderCeiling)
                    }
                    .padding(.top, 32)

                    RFFieldGroup(title: "Zustand") {
                        FlowRow(spacing: 8) {
                            ForEach(Condition.allCases) { condition in
                                Button {
                                    store.draft.condition = condition
                                } label: {
                                    RFChip(title: condition.displayName,
                                           selected: store.draft.condition == condition,
                                           caps: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 34)

                    RFFieldGroup(title: "Region & Laufzeit") {
                        RFSettingRow(title: store.draft.regionLine) { editingRegion = true }
                        RFSettingRow(title: store.draft.durationLine) { editingDuration = true }
                    }
                    .padding(.top, 34)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.top, RF.Metric.topInsetFlow)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Weiter", action: onNext)
                .buttonStyle(RFButtonStyle(kind: store.draft.budgetIsValid ? .primary : .disabled))
                .disabled(!store.draft.budgetIsValid)
                .accessibilityIdentifier("post.details.next")
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.bottom, 12)
        }
        .sheet(isPresented: $editingRegion) {
            RFChoiceSheet(title: "Region",
                          options: RegionOption.all,
                          label: \.name,
                          selection: Binding(
                            get: { RegionOption(name: store.draft.region) },
                            set: { store.draft.region = $0.name; editingRadius = true }
                          ))
        }
        .sheet(isPresented: $editingRadius) {
            RFChoiceSheet(title: "Umkreis",
                          options: RadiusOption.all,
                          label: { "\($0.km) km" },
                          selection: Binding(
                            get: { RadiusOption(km: store.draft.radiusKm) },
                            set: { store.draft.radiusKm = $0.km }
                          ))
        }
        .sheet(isPresented: $editingDuration) {
            RFChoiceSheet(title: "Laufzeit",
                          options: DurationOption.all,
                          label: { "\($0.days) Tage" },
                          selection: Binding(
                            get: { DurationOption(days: store.draft.durationDays) },
                            set: { store.draft.durationDays = $0.days }
                          ))
        }
    }
}

#Preview("05 Details") {
    PostDetailsStep(store: PostWantStore(repository: MockRefindRepository.instant, city: "Zürich"),
                    onBack: {}, onNext: {})
}
