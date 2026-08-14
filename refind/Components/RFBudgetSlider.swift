//
//  RFBudgetSlider.swift
//  refind
//
//  3 pt track, ink fill to the value, 26 pt ink knob. No system slider — the
//  stock one brings its own tint, shadow and knob chrome, none of which belong.
//
//  The amount is typed as well as dragged: the big figure is the input, and the
//  track is there for coarse adjustment. Dragging alone made an exact budget
//  (CHF 2'350) tedious, and the send-offer sheet already types its price, so
//  this is also the app agreeing with itself.
//

import SwiftUI

struct RFBudgetSlider: View {
    @Binding var value: Money
    /// Upper end of the track, in CHF. Grows to fit whatever is entered.
    @Binding var ceiling: Int

    var step: Int = 50
    /// Hard limit from the handoff's validation rules.
    var absoluteMax: Int = 100_000

    private let knobSize: CGFloat = 26
    private let trackHeight: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var editing: Bool
    @State private var text = ""
    /// Restored if the field is opened and left empty.
    @State private var previousCHF = 0

    private var chf: Int { value.minorUnits / 100 }

    private var fraction: Double {
        guard ceiling > 0 else { return 0 }
        return min(1, max(0, Double(chf) / Double(ceiling)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            valueRow
            track
            HStack {
                Text(Money(chf: 0).formatted).rfLabel(10)
                Spacer()
                Text(Money(chf: ceiling).formatted).rfLabel(10)
            }
        }
        .onAppear { syncText() }
        .onChange(of: value) { _, _ in if !editing { syncText() } }
        // Tapping the figure starts a fresh amount rather than appending to the
        // one already there — typing "2350" over "2'000" otherwise reads as
        // 20'002'350 and slams into the cap. Leaving it untouched restores it.
        .onChange(of: editing) { _, isEditing in
            if isEditing {
                previousCHF = chf
                text = ""
            } else if text.isEmpty {
                value = Money(chf: previousCHF)
                syncText()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { editing = false }
                    .font(RF.ui(15, weight: .medium))
                    .foregroundStyle(RF.Palette.ink)
            }
        }
    }

    /// The figure is the field. Tapping the number puts a caret in it.
    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("CHF")
                    .font(RF.num(30, weight: .medium))
                    .foregroundStyle(RF.Palette.ink)
                TextField("0", text: $text)
                    .font(RF.num(30, weight: .medium))
                    .foregroundStyle(RF.Palette.ink)
                    .keyboardType(.numberPad)
                    .tint(RF.Palette.offer)
                    .focused($editing)
                    .fixedSize()
                    .onChange(of: text) { _, new in textChanged(new) }
                    .accessibilityLabel("Budget in Franken")
            }
            // The rule hugs the figure rather than the row: run full width and
            // it reads as a divider above the track instead of an input.
            .frame(minWidth: 190, alignment: .leading)
            .overlay(alignment: .bottomLeading) {
                Rectangle()
                    .fill(editing ? RF.Palette.ink : RF.Palette.line)
                    .frame(height: editing ? RF.Metric.inputRule : RF.Metric.hairline)
                    .offset(y: 8)
            }

            Text("max.")
                .font(RF.num(12, weight: .medium))
                .foregroundStyle(RF.Palette.muted)
            Spacer(minLength: 0)
        }
    }

    private var track: some View {
        GeometryReader { geo in
            // The knob travels inset by its own radius so it never hangs off
            // either end of the track.
            let travel = max(1, geo.size.width - knobSize)
            let x = knobSize / 2 + travel * fraction

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(RF.Palette.line)
                    .frame(height: trackHeight)
                Rectangle()
                    .fill(RF.Palette.ink)
                    .frame(width: x, height: trackHeight)
                Circle()
                    .fill(RF.Palette.ink)
                    .frame(width: knobSize, height: knobSize)
                    .position(x: x, y: trackHeight / 2)
            }
            .frame(height: knobSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        editing = false
                        setCHF(Int((Double((drag.location.x - knobSize / 2) / travel)
                                    * Double(ceiling)).rounded()))
                    }
                    .onEnded { _ in growCeilingIfAtEnd() }
            )
        }
        .frame(height: knobSize)
        .padding(.top, 22)
        .padding(.bottom, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Budget")
        .accessibilityValue(value.formatted)
        .accessibilityAdjustableAction { direction in
            setCHF(chf + (direction == .increment ? step : -step))
            growCeilingIfAtEnd()
        }
    }

    // MARK: Value plumbing

    private func syncText() {
        text = chf == 0 ? "" : Money(chf: chf).digitsOnly
    }

    private func textChanged(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        let entered = min(Int(digits) ?? 0, absoluteMax)
        value = Money(chf: entered)
        // A typed amount above the track's end lifts the ceiling rather than
        // being clamped down to it.
        growCeiling(toFit: entered)
        let grouped = entered == 0 ? "" : Money(chf: entered).digitsOnly
        if grouped != raw { text = grouped }
    }

    private func setCHF(_ candidate: Int) {
        let stepped = (Double(candidate) / Double(step)).rounded() * Double(step)
        let clamped = min(max(0, Int(stepped)), min(ceiling, absoluteMax))
        guard clamped != chf else { return }
        value = Money(chf: clamped)
    }

    /// The mock's track ends at CHF 3'200, but a want may be worth up to
    /// CHF 100'000. Rather than cap the product at the drawn number, the
    /// ceiling doubles once the knob reaches it.
    private func growCeilingIfAtEnd() {
        guard fraction >= 1, ceiling < absoluteMax else { return }
        withAnimation(reduceMotion ? nil : RF.Motion.entrance) {
            ceiling = min(ceiling * 2, absoluteMax)
        }
    }

    private func growCeiling(toFit amount: Int) {
        guard amount > ceiling else { return }
        var next = max(ceiling, 1)
        while next < amount, next < absoluteMax { next = min(next * 2, absoluteMax) }
        ceiling = next
    }
}

#Preview("Budget") {
    @Previewable @State var value = Money(chf: 2_000)
    @Previewable @State var ceiling = 3_200
    return ZStack {
        RF.Palette.paper.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 10) {
            Text("Budget").rfLabel(10)
            RFBudgetSlider(value: $value, ceiling: $ceiling)
        }
        .padding(RF.Metric.screenMargin)
    }
}
