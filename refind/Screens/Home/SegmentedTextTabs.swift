//
//  SegmentedTextTabs.swift
//  refind
//
//  Text tabs with a 2 pt underline that sits on the section's hairline rule,
//  not below it.
//

import SwiftUI

struct SegmentedTextTabs: View {
    @Binding var selection: HomeStore.Segment

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(RF.Palette.line)
                .frame(height: RF.Metric.hairline)
            HStack(alignment: .bottom, spacing: 22) {
                ForEach(HomeStore.Segment.allCases) { segment in
                    item(segment)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, RF.Metric.screenMargin)
        }
    }

    private func item(_ segment: HomeStore.Segment) -> some View {
        let isSelected = segment == selection
        return Button {
            selection = segment
        } label: {
            Text(segment.title)
                .font(RF.ui(15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? RF.Palette.ink : RF.Palette.muted)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? RF.Palette.ink : .clear)
                        .frame(height: 2)
                }
                .frame(minHeight: RF.Metric.minHitTarget, alignment: .bottom)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(segment.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
