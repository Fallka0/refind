//
//  RFFlowChrome.swift
//  refind
//
//  Shared furniture for the modal flows: the step header and the settings row
//  with an "ändern" affordance.
//

import SwiftUI

/// "Abbrechen · SCHRITT 1 / 3"
struct RFFlowHeader: View {
    let leadingTitle: String
    let step: Int
    var totalSteps: Int = 3
    let onLeading: () -> Void

    var body: some View {
        HStack {
            Button(leadingTitle, action: onLeading)
                .font(RF.ui(15))
                .foregroundStyle(RF.Palette.muted)
                .frame(minHeight: RF.Metric.minHitTarget, alignment: .leading)
            Spacer()
            Text("Schritt \(step) / \(totalSteps)").rfLabel(10)
        }
        .accessibilityElement(children: .contain)
    }
}

/// White card row: a value on the left, "ändern" on the right.
struct RFSettingRow: View {
    let title: String
    var actionTitle: String = "ändern"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RFCard(padding: 0) {
                HStack {
                    Text(title)
                        .font(RF.ui(15))
                        .foregroundStyle(RF.Palette.ink)
                    Spacer()
                    Text(actionTitle)
                        .font(RF.ui(15))
                        .foregroundStyle(RF.Palette.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(actionTitle)
    }
}

/// A labelled block — "BUDGET", "ZUSTAND", "REGION & LAUFZEIT".
struct RFFieldGroup<Content: View>: View {
    let title: String
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title).rfLabel(10)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The picker behind "ändern": a sheet of chips, one choice.
struct RFChoiceSheet<Option: Hashable & Identifiable>: View {
    let title: String
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 26) {
                Text(title)
                    .font(RF.display(32))
                    .foregroundStyle(RF.Palette.ink)
                FlowRow(spacing: 10) {
                    ForEach(options) { option in
                        Button {
                            selection = option
                            dismiss()
                        } label: {
                            RFChip(title: label(option),
                                   selected: option == selection,
                                   caps: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 34)
        }
        .presentationDetents([.height(280)])
        .presentationCornerRadius(RF.Metric.sheetRadius)
    }
}
