//
//  RFMockPhoto.swift
//  refind
//
//  No image assets ship with the app, and the mocks left every photo as an
//  empty drop slot. This draws a deterministic stand-in from a seed string:
//  the same offer always gets the same picture, and the whole thing stays
//  inside the palette so a screen full of them still reads as refind.
//
//  Swap for a real AsyncImage behind the same call site once listings carry
//  photo URLs.
//

import SwiftUI

struct RFMockPhoto: View {
    let seed: String
    var cornerRadius: CGFloat = RF.Metric.cardRadius
    var bordered: Bool = true

    var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(seed: seed)
            let composition = Composition.allCases.randomElement(using: &rng) ?? .arc
            composition.draw(in: &context, size: size, rng: &rng)
        }
        .background(RF.Palette.cardAlt)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            if bordered {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(RF.Palette.line, lineWidth: RF.Metric.hairline)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Compositions

    private enum Composition: CaseIterable {
        case arc, band, stack, corner

        func draw(in context: inout GraphicsContext, size: CGSize, rng: inout SeededGenerator) {
            let w = size.width, h = size.height
            let tones: [Color] = [RF.Palette.ink, RF.Palette.muted, RF.Palette.lineStrong]

            switch self {
            case .arc:
                let r = w * Double.random(in: 0.45...0.7, using: &rng)
                let cx = w * Double.random(in: 0.3...0.7, using: &rng)
                let cy = h * Double.random(in: 0.45...0.8, using: &rng)
                context.fill(
                    Circle().path(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                    with: .color(tones[0].opacity(0.14))
                )
                context.fill(
                    Circle().path(in: CGRect(x: cx - r * 0.4, y: cy - r * 0.4,
                                             width: r * 0.8, height: r * 0.8)),
                    with: .color(tones[1].opacity(0.22))
                )

            case .band:
                let bandHeight = h * Double.random(in: 0.18...0.32, using: &rng)
                let y = h * Double.random(in: 0.25...0.55, using: &rng)
                context.fill(
                    Rectangle().path(in: CGRect(x: 0, y: y, width: w, height: bandHeight)),
                    with: .color(tones[0].opacity(0.16))
                )
                context.fill(
                    Rectangle().path(in: CGRect(x: w * 0.12, y: y + bandHeight,
                                                width: w * 0.34, height: h * 0.2)),
                    with: .color(tones[2].opacity(0.5))
                )

            case .stack:
                let count = Int.random(in: 2...3, using: &rng)
                for i in 0..<count {
                    let inset = Double(i) * min(w, h) * 0.14
                    let rect = CGRect(x: w * 0.16 + inset, y: h * 0.16 + inset,
                                      width: w * 0.68 - inset * 2, height: h * 0.68 - inset * 2)
                    context.stroke(
                        Rectangle().path(in: rect),
                        with: .color(tones[i % tones.count].opacity(0.28)),
                        lineWidth: max(1, min(w, h) * 0.02)
                    )
                }

            case .corner:
                var path = Path()
                path.move(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: w * Double.random(in: 0.5...0.9, using: &rng), y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
                context.fill(path, with: .color(tones[0].opacity(0.12)))
                let dot = min(w, h) * 0.18
                context.fill(
                    Circle().path(in: CGRect(x: w * 0.18, y: h * 0.2, width: dot, height: dot)),
                    with: .color(tones[1].opacity(0.35))
                )
            }
        }
    }
}

/// Deterministic PRNG so a given seed always draws the same picture.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325     // FNV-1a
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x1000_0000_01b3
        }
        state = hash == 0 ? 0x9e37_79b9_7f4a_7c15 : hash
    }

    mutating func next() -> UInt64 {                  // SplitMix64
        state = state &+ 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}

#Preview("Mock photos") {
    ZStack {
        RF.Palette.paper.ignoresSafeArea()
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ForEach(["omega-1", "omega-2", "eames-1", "leica-1"], id: \.self) { seed in
                    RFMockPhoto(seed: seed)
                        .frame(width: RF.Metric.offerPhotoLarge, height: RF.Metric.offerPhotoLarge)
                }
            }
            RFMockPhoto(seed: "werk-detail", cornerRadius: RF.Metric.photoAttachmentRadius)
                .frame(width: RF.Metric.photoAttachmentWidth, height: RF.Metric.photoAttachmentHeight)
        }
    }
}
