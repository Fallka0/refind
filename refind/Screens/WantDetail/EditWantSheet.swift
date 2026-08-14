//
//  EditWantSheet.swift
//  refind
//
//  "Bearbeiten" on screen 07. Not drawn in the handoff, so it reuses the post
//  flow's own fields rather than inventing a second visual language for the
//  same data — title, budget, condition, region, duration.
//

import SwiftUI

struct EditWantSheet: View {
    let want: Want
    var onSaved: (Want) -> Void = { _ in }

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var draft = WantDraft()
    @State private var ceiling = 3_200
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var editingRegion = false
    @State private var editingDuration = false

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Gesuch bearbeiten")
                        .font(RF.display(32))
                        .foregroundStyle(RF.Palette.ink)

                    RFFieldGroup(title: "Titel", spacing: 10) {
                        RFUnderlineField(placeholder: "Was suchst du?", text: $draft.title)
                    }
                    .padding(.top, 26)

                    RFFieldGroup(title: "Budget", spacing: 10) {
                        RFBudgetSlider(value: $draft.budgetMax, ceiling: $ceiling)
                    }
                    .padding(.top, 30)

                    RFFieldGroup(title: "Zustand") {
                        FlowRow(spacing: 8) {
                            ForEach(Condition.allCases) { condition in
                                Button {
                                    draft.condition = condition
                                } label: {
                                    RFChip(title: condition.displayName,
                                           selected: draft.condition == condition,
                                           caps: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 30)

                    RFFieldGroup(title: "Region & Laufzeit") {
                        RFSettingRow(title: draft.regionLine) { editingRegion = true }
                        RFSettingRow(title: draft.durationLine) { editingDuration = true }
                    }
                    .padding(.top, 30)

                    if let errorMessage {
                        Text(errorMessage.uppercased())
                            .rfLabel(11, color: RF.Palette.offer)
                            .padding(.top, 18)
                    }

                    Spacer(minLength: 30)

                    VStack(spacing: 12) {
                        Button(isSaving ? "Wird gespeichert …" : "Speichern") { save() }
                            .buttonStyle(RFButtonStyle(kind: draft.isValid && !isSaving
                                                       ? .primary : .disabled))
                            .disabled(!draft.isValid || isSaving)
                            .accessibilityIdentifier("edit.save")
                        Button("Abbrechen") { dismiss() }
                            .buttonStyle(RFButtonStyle(kind: .secondary))
                    }
                }
                .padding(.horizontal, RF.Metric.screenMargin)
                .padding(.top, 34)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .presentationCornerRadius(RF.Metric.sheetRadius)
        .presentationBackground(RF.Palette.paper)
        .onAppear { seed() }
        .sheet(isPresented: $editingRegion) {
            RFChoiceSheet(title: "Region", options: RegionOption.all, label: \.name,
                          selection: Binding(get: { RegionOption(name: draft.region) },
                                             set: { draft.region = $0.name }))
        }
        .sheet(isPresented: $editingDuration) {
            RFChoiceSheet(title: "Laufzeit", options: DurationOption.all,
                          label: { "\($0.days) Tage" },
                          selection: Binding(get: { DurationOption(days: draft.durationDays) },
                                             set: { draft.durationDays = $0.days }))
        }
    }

    private func seed() {
        draft.title = want.title
        draft.category = want.category
        draft.budgetMax = want.budgetMax
        draft.condition = want.condition
        draft.region = want.region
        draft.radiusKm = want.radiusKm
        draft.durationDays = max(1, Int((want.expiresAt.timeIntervalSinceNow / 86_400).rounded()))
        // Keep the track meaningful for whatever the want already costs.
        while ceiling < (want.budgetMax.minorUnits / 100), ceiling < 100_000 {
            ceiling = min(ceiling * 2, 100_000)
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let updated = try await environment.repository.updateWant(id: want.id, draft: draft)
                onSaved(updated)
                dismiss()
            } catch {
                errorMessage = (error as? RepositoryError)?.inlineMessage
                    ?? RepositoryError.server.inlineMessage
            }
            isSaving = false
        }
    }
}
