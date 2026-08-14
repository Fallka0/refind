//
//  DesignSystem.swift
//  refind — design tokens derived from the HTML design system (v1)
//
//  Fonts must be bundled and declared in Info.plist under UIAppFonts:
//    InstrumentSerif-Regular.ttf, Archivo-Regular.ttf, Archivo-Medium.ttf, Archivo-SemiBold.ttf
//  Two families only — there is no monospace in the brand.
//

import SwiftUI

// MARK: - Color

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum RF {

    // MARK: Palette
    enum Palette {
        /// All text, primary buttons, mascot outline, active icons.
        static let ink        = Color(hex: 0x1A1917)
        /// Default screen surface.
        static let paper      = Color(hex: 0xEDEBE7)
        /// Cards, sheets, incoming bubbles, inputs.
        static let card       = Color(hex: 0xFFFFFF)
        /// Expired / disabled cards.
        static let cardAlt    = Color(hex: 0xF7F6F3)
        /// RESERVED for offers, prices, live state, badges. Never a large fill.
        static let offer      = Color(hex: 0xB5442A)
        /// Secondary text, inactive icons, meta.
        static let muted      = Color(hex: 0x8C877E)
        /// Hairlines and card borders.
        static let line       = Color(hex: 0xDCD8D2)
        /// Dashed empty-state borders, expired mascot.
        static let lineStrong = Color(hex: 0xC9C4BC)
        /// Body text on white.
        static let inkSoft    = Color(hex: 0x3A3833)
        /// Secondary body copy.
        static let inkMid     = Color(hex: 0x5C5850)
    }

    // MARK: Typography
    enum Font_ {
        static let serif = "InstrumentSerif-Regular"
        static let sans  = "Archivo-Regular"
        static let sansMedium = "Archivo-Medium"
        static let sansSemibold = "Archivo-SemiBold"
    }

    /// Instrument Serif — screen titles (34–44), item titles (24–32), the wordmark.
    static func display(_ size: CGFloat) -> Font {
        .custom(Font_.serif, size: size, relativeTo: size >= 34 ? .largeTitle : .title)
    }
    /// Archivo — UI labels and body.
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String = weight == .semibold ? Font_.sansSemibold
                         : weight == .medium   ? Font_.sansMedium
                         : Font_.sans
        return .custom(name, size: size, relativeTo: size >= 17 ? .headline : .body)
    }
    /// Small caps label — meta, section heads, timestamps.
    /// Always uppercase the string and keep the tracking; figures are tabular.
    static func label(_ size: CGFloat = 10) -> Font {
        .custom(Font_.sansMedium, size: size, relativeTo: .caption).monospacedDigit()
    }
    /// Numbers that must align in columns (prices, totals).
    static func num(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        ui(size, weight: weight).monospacedDigit()
    }

    // MARK: Metrics
    enum Metric {
        static let screenMargin: CGFloat = 24
        static let tabBarMargin: CGFloat = 16
        /// First content row below the overlaying status bar.
        static let topInsetTabbed: CGFloat = 62
        static let topInsetFlow: CGFloat = 66

        static let cardPadding: CGFloat = 18
        static let cardGap: CGFloat = 14
        static let hairline: CGFloat = 1
        static let cardRadius: CGFloat = 0        // square corners are a brand signature
        static let sheetRadius: CGFloat = 26
        static let bubbleRadius: CGFloat = 18
        static let bubbleTail: CGFloat = 4
        static let buttonHeight: CGFloat = 52
        static let minHitTarget: CGFloat = 44
        static let inputRule: CGFloat = 1.5
    }

    // MARK: Motion
    enum Motion {
        static let entrance = Animation.spring(response: 0.5, dampingFraction: 0.85)
        static let stagger: Double = 0.08
        static let sheet = Animation.spring(response: 0.5, dampingFraction: 0.85)
        static let logoReveal = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 1.1)
        static let bobIdle: Double = 3.4
        static let bobHappy: Double = 1.1
        static let tilt: Double = 3.6
        static let scan: Double = 1.8
        static let blink: Double = 4.2
        static let typingDots: Double = 1.2
        static let sparkle: Double = 1.4
        static let pulse: Double = 2.0
    }

    // MARK: Formatting
    /// "CHF 1'720" — Swiss German grouping.
    static func price(_ amount: Decimal, showCurrency: Bool = true) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "\u{2019}"   // CHF 1'720 — Swiss apostrophe
        let value = f.string(from: amount as NSDecimalNumber) ?? "0"
        return showCurrency ? "CHF \(value)" : value
    }
}

// MARK: - Text helpers

extension Text {
    /// The brand's small label: Archivo Medium, uppercase, +12% tracking, muted by default.
    /// Pass the string already written in caps, or use `.textCase(.uppercase)`.
    func rfLabel(_ size: CGFloat = 10, tracking: CGFloat? = nil, color: Color = RF.Palette.muted) -> some View {
        self.font(RF.label(size))
            .tracking(tracking ?? size * 0.12)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Surfaces

/// The standard refind card: white, square, 1 pt hairline border.
struct RFCard<Content: View>: View {
    var padding: CGFloat = RF.Metric.cardPadding
    var borderColor: Color = RF.Palette.line
    var background: Color = RF.Palette.card
    var dashed: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay {
                Rectangle().strokeBorder(
                    borderColor,
                    style: StrokeStyle(lineWidth: RF.Metric.hairline,
                                       dash: dashed ? [4, 4] : [])
                )
            }
    }
}

// MARK: - Buttons

enum RFButtonKind { case primary, secondary, offerOutline, offerFilled, disabled }

struct RFButtonStyle: ButtonStyle {
    var kind: RFButtonKind = .primary

    func makeBody(configuration: Configuration) -> some View {
        let fg: Color, bg: Color, border: Color?
        switch kind {
        case .primary:      fg = RF.Palette.paper; bg = RF.Palette.ink;   border = nil
        case .secondary:    fg = RF.Palette.ink;   bg = .clear;           border = RF.Palette.ink
        case .offerOutline: fg = RF.Palette.offer; bg = .clear;           border = RF.Palette.offer
        case .offerFilled:  fg = .white;           bg = RF.Palette.offer; border = nil
        case .disabled:     fg = RF.Palette.muted; bg = RF.Palette.line;  border = nil
        }
        return configuration.label
            .font(RF.ui(16, weight: .medium))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: RF.Metric.buttonHeight)
            .background(bg, in: Capsule())
            .overlay { if let border { Capsule().strokeBorder(border, lineWidth: 1) } }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Chip

struct RFChip: View {
    let title: String
    var selected: Bool = false
    /// Small tracked caps (filters, categories) vs. sentence-case chips (conditions).
    var caps: Bool = true

    var body: some View {
        Text(caps ? title.uppercased() : title)
            .font(caps ? RF.label(11) : RF.ui(13, weight: .medium))
            .tracking(caps ? 1.3 : 0)
            .foregroundStyle(selected ? RF.Palette.paper : RF.Palette.inkMid)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(minHeight: RF.Metric.minHitTarget)
            .background(selected ? RF.Palette.ink : RF.Palette.card, in: Capsule())
            .overlay { if !selected { Capsule().strokeBorder(RF.Palette.line, lineWidth: 1) } }
    }
}

// MARK: - Live / status marks

struct RFLiveDot: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(RF.Palette.offer).frame(width: 6, height: 6)
            Text("LIVE").rfLabel(10, color: RF.Palette.offer)
        }
    }
}

/// Offer count badge with the outward pulse ring.
struct RFOfferBadge: View {
    let count: Int
    var size: CGFloat = 26
    @State private var animate = false

    var body: some View {
        Text("\(count)")
            .font(RF.num(11))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RF.Palette.offer, in: Circle())
            .overlay {
                Circle()
                    .stroke(RF.Palette.offer.opacity(animate ? 0 : 0.45), lineWidth: 8)
                    .scaleEffect(animate ? 1.9 : 1)
            }
            .onAppear {
                withAnimation(.easeOut(duration: RF.Motion.pulse).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

/// The single-rule text field used across the app.
struct RFUnderlineField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(placeholder, text: $text)
                .font(RF.ui(20))
                .tint(RF.Palette.offer)
            Rectangle()
                .fill(RF.Palette.ink)
                .frame(height: RF.Metric.inputRule)
        }
    }
}
