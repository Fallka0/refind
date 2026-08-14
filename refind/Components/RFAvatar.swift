//
//  RFAvatar.swift
//  refind
//
//  Two kinds: the signet (ink circle, serif initial — that is the logo suite's
//  avatar mark, used for the current user) and a photo avatar for other people.
//

import SwiftUI

struct RFAvatar: View {
    enum Style {
        /// Ink circle with the initial in Instrument Serif — the brand signet.
        case signet
        /// A person's picture. Falls back to the signet when there is no photo.
        case photo(seed: String)
    }

    let initial: String
    var style: Style = .signet
    var size: CGFloat = RF.Metric.avatarChatRow

    var body: some View {
        Group {
            switch style {
            case .signet:
                Circle()
                    .fill(RF.Palette.ink)
                    .overlay {
                        Text(initial.lowercased())
                            .font(RF.display(size * 0.55))
                            .foregroundStyle(RF.Palette.paper)
                    }
            case .photo(let seed):
                RFMockPhoto(seed: seed, cornerRadius: size / 2, bordered: false)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

extension RFAvatar {
    /// The avatar for another user — their picture, seeded by their id.
    init(user: User, size: CGFloat = RF.Metric.avatarChatRow) {
        self.init(initial: user.initial, style: .photo(seed: "avatar-\(user.id)"), size: size)
    }
}

#Preview("Avatars") {
    ZStack {
        RF.Palette.paper.ignoresSafeArea()
        HStack(spacing: 16) {
            RFAvatar(initial: "r", style: .signet, size: RF.Metric.avatarHeader)
            RFAvatar(user: MockSeed.marc, size: RF.Metric.avatarChatRow)
            RFAvatar(user: MockSeed.nina, size: RF.Metric.avatarProfile)
        }
    }
}
