//
//  FinMascot.swift
//  refind — "Fin", the want-note mascot.
//
//  Fin IS a Gesuch: a slip of paper with the top-right corner cut off.
//  Everything is primitives — no image assets.
//
//  Rules (from the design system):
//   • Max one Fin per screen.
//   • Fin speaks only in onboarding, empty states and success moments.
//     Never inside a negotiation chat — there, only humans speak.
//   • Below 24 pt: body + eyes only (handled automatically via `compact`).
//   • Honour Reduce Motion: animations collapse to a static pose.
//

import SwiftUI

// MARK: - The note shape

/// Rectangle with a cut top-right corner: polygon(0 0, 72% 0, 100% 24%, 100% 100%, 0 100%)
struct NoteShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.24))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The folded corner, drawn over the top-right cut.
private struct FoldShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - States

enum FinState {
    /// Splash, ambient. Blink + slow bob.
    case idle
    /// Onboarding, tutorial prompts, upsells. Tilt + red "?".
    case asking
    /// Want is live, waiting for offers. Scanning eyes + typing dots.
    case searching
    /// New offer / deal confirmed. Red outline, fast bob, sparkles.
    case offerReceived
    /// Empty lists, expired want. Grey, rotated, dash eyes.
    case empty

    var outline: Color {
        switch self {
        case .offerReceived: return RF.Palette.offer
        case .empty:         return RF.Palette.lineStrong
        default:             return RF.Palette.ink
        }
    }
    var fill: Color { self == .empty ? RF.Palette.cardAlt : RF.Palette.card }
    var featureColor: Color { self == .empty ? RF.Palette.muted : RF.Palette.ink }
}

// MARK: - The view

struct FinMascot: View {
    var state: FinState = .idle
    /// Height in points. Width follows at a 0.84 ratio (104 × 124 reference).
    var height: CGFloat = 124
    /// Renders Fin in a single light colour (splash on ink, small badges).
    var monochrome: Color? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    private var width: CGFloat { height * 0.84 }
    private var compact: Bool { height < 24 * 1.2 }
    private var unit: CGFloat { height / 124 }          // scale factor vs. reference
    private var strokeInset: CGFloat { max(1.5, 3 * unit) }

    var body: some View {
        ZStack {
            body_
            if !compact { features }
            decorations
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(state == .empty ? -8 : 0))
        .offset(y: bobOffset)
        .rotationEffect(.degrees(tiltAngle))
        .accessibilityHidden(true)
        .onAppear { startLoop() }
    }

    // MARK: pieces

    @ViewBuilder private var body_: some View {
        if let mono = monochrome {
            NoteShape().fill(mono)
        } else {
            ZStack {
                NoteShape().fill(state.outline)
                NoteShape().fill(state.fill).padding(strokeInset)
                FoldShape()
                    .fill(state.outline)
                    .frame(width: 28 * unit, height: 28 * unit)
                    .position(x: width - 14 * unit - strokeInset, y: 14 * unit + strokeInset)
            }
        }
    }

    @ViewBuilder private var features: some View {
        let eye = eyeSize
        VStack(spacing: 15 * unit) {
            HStack(spacing: eyeGap) {
                eyeView(eye); eyeView(eye)
            }
            .offset(x: state == .searching && !reduceMotion ? (phase ? 3 * unit : -3 * unit) : 0)
            mouth
        }
        .offset(y: 6 * unit)
    }

    @ViewBuilder private func eyeView(_ size: CGFloat) -> some View {
        let color = monochrome == nil ? state.featureColor : RF.Palette.ink
        if state == .empty {
            Rectangle().fill(color).frame(width: 14 * unit, height: 2.5 * unit)
        } else {
            let eye = Circle().fill(color).frame(width: size, height: size)
            // The blink runs on its own clock, not on `phase`: it is a spike inside a
            // long hold (scaleY 1 → 0.1 → 1 within 4% of the 4.2 s loop), which the
            // shared autoreversing sine cannot express.
            if state == .idle, !reduceMotion {
                eye.keyframeAnimator(initialValue: 1.0, repeating: true) { view, scale in
                    view.scaleEffect(y: scale, anchor: .center)
                } keyframes: { _ in
                    LinearKeyframe(1.0, duration: RF.Motion.blink - 2 * Self.blinkHalf)
                    LinearKeyframe(0.1, duration: Self.blinkHalf)
                    LinearKeyframe(1.0, duration: Self.blinkHalf)
                }
            } else {
                eye
            }
        }
    }

    /// Half a blink: lid down, lid up. 2 × 0.085 s ≈ 4% of the 4.2 s loop.
    private static let blinkHalf: Double = 0.085

    @ViewBuilder private var mouth: some View {
        let color = monochrome == nil ? state.featureColor : RF.Palette.ink
        switch state {
        case .idle:
            Smile().stroke(color, lineWidth: 2.5 * unit)
                .frame(width: 20 * unit, height: 10 * unit)
        case .asking:
            Circle().fill(color).frame(width: 12 * unit, height: 12 * unit)
        case .searching:
            Rectangle().fill(color).frame(width: 18 * unit, height: 2.5 * unit)
        case .offerReceived:
            UnevenRoundedRectangle(bottomLeadingRadius: 16 * unit, bottomTrailingRadius: 16 * unit)
                .fill(color).frame(width: 26 * unit, height: 14 * unit)
        case .empty:
            Smile().stroke(color, lineWidth: 2.5 * unit)
                .frame(width: 20 * unit, height: 10 * unit)
                .rotationEffect(.degrees(180))
        }
    }

    @ViewBuilder private var decorations: some View {
        switch state {
        case .asking:
            Text("?")
                .font(RF.display(44 * unit))
                .foregroundStyle(RF.Palette.offer)
                .scaleEffect(reduceMotion ? 1 : (phase ? 1.1 : 0.85))
                .offset(x: width * 0.55, y: -height * 0.42)
        case .searching:
            HStack(spacing: 6 * unit) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(RF.Palette.muted)
                        .frame(width: 6 * unit, height: 6 * unit)
                        .opacity(reduceMotion ? 0.6 : (phase ? 1 : 0.25))
                        .animation(reduceMotion ? nil :
                            .easeInOut(duration: RF.Motion.typingDots / 2)
                            .repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .offset(y: height * 0.62)
        case .offerReceived:
            Group {
                Text("✦").font(.system(size: 18 * unit))
                    .offset(x: -width * 0.6, y: -height * 0.45)
                Text("✦").font(.system(size: 13 * unit))
                    .offset(x: width * 0.62, y: -height * 0.28)
            }
            .foregroundStyle(RF.Palette.offer)
            .scaleEffect(reduceMotion ? 1 : (phase ? 1 : 0.6))
            .opacity(reduceMotion ? 1 : (phase ? 1 : 0.2))
        default:
            EmptyView()
        }
    }

    // MARK: geometry & motion

    private var eyeSize: CGFloat {
        switch state {
        case .asking:         return 13 * unit
        case .offerReceived:  return 14 * unit
        default:              return 11 * unit
        }
    }
    private var eyeGap: CGFloat { state == .offerReceived ? 16 * unit : 18 * unit }

    private var bobOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        switch state {
        case .idle, .offerReceived: return phase ? -6 : 0
        default: return 0
        }
    }
    private var tiltAngle: Double {
        guard !reduceMotion, state == .asking else { return 0 }
        return phase ? 5 : -5
    }

    private func startLoop() {
        guard !reduceMotion else { return }
        let duration: Double
        switch state {
        case .idle:          duration = RF.Motion.bobIdle / 2
        case .offerReceived: duration = RF.Motion.bobHappy / 2
        case .asking:        duration = RF.Motion.tilt / 2
        case .searching:     duration = RF.Motion.scan / 2
        case .empty:         return
        }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            phase = true
        }
    }
}

/// The idle smile: a downward arc.
private struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 2))
        return p
    }
}

// MARK: - Speech card (onboarding / tutorial)

/// Fin plus a speech card. Used for onboarding steps and upsell rows.
struct FinSays<Content: View>: View {
    var state: FinState = .asking
    var mascotHeight: CGFloat = 74
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            FinMascot(state: state, height: mascotHeight)
                // `asking` pops a "?" above the note's frame; without room for
                // it the glyph is clipped by the row's bounds.
                .padding(.top, state == .asking ? mascotHeight * 0.2 : 0)
            content
                .font(RF.ui(15))
                .foregroundStyle(RF.Palette.ink)
                .padding(.vertical, 16).padding(.horizontal, 18)
                .background(RF.Palette.card,
                            in: UnevenRoundedRectangle(topLeadingRadius: 18,
                                                       bottomLeadingRadius: 4,
                                                       bottomTrailingRadius: 18,
                                                       topTrailingRadius: 18))
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4,
                                           bottomTrailingRadius: 18, topTrailingRadius: 18)
                        .strokeBorder(RF.Palette.line, lineWidth: 1)
                }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview("Fin states") {
    ZStack {
        RF.Palette.paper.ignoresSafeArea()
        VStack(spacing: 40) {
            HStack(spacing: 32) {
                FinMascot(state: .idle)
                FinMascot(state: .asking)
                FinMascot(state: .searching)
            }
            HStack(spacing: 32) {
                FinMascot(state: .offerReceived)
                FinMascot(state: .empty)
                FinMascot(state: .idle, height: 40)
            }
            FinSays { Text("Hoi, ich bin Fin. Hier zählt, was du suchst – nicht, was du loswerden willst.") }
                .padding(.horizontal, 24)
        }
    }
}
