//
//  Tokens+App.swift
//  refind
//
//  Values the designs specify but the handoff's DesignSystem.swift does not
//  tokenise. They live here rather than inline in a view, so there is still
//  exactly one place a radius or a size is written down.
//  DesignSystem.swift itself stays byte-identical to the handoff.
//

import SwiftUI

extension RF.Metric {
    /// Photo attachments in a chat thread: 200 × 150, radius 14.
    static let photoAttachmentRadius: CGFloat = 14
    static let photoAttachmentWidth: CGFloat = 200
    static let photoAttachmentHeight: CGFloat = 150

    /// Avatars, by use site.
    static let avatarHeader: CGFloat = 36      // home header
    static let avatarFeed: CGFloat = 28        // Entdecken card
    static let avatarChatRow: CGFloat = 44     // chat list
    static let avatarChatHeader: CGFloat = 34  // negotiation header
    static let avatarProfile: CGFloat = 68     // profile

    /// Offer photos: 84 pt on the emphasised card, 60 pt on compact rows.
    static let offerPhotoLarge: CGFloat = 84
    static let offerPhotoCompact: CGFloat = 60
    /// Photo slots in the send-offer sheet.
    static let offerPhotoSlot: CGFloat = 88

    /// Badges: 26 pt on a want card, 22 pt on a chat row.
    static let badgeLarge: CGFloat = 26
    static let badgeSmall: CGFloat = 22

    /// The sheet grabber.
    static let grabberWidth: CGFloat = 44
    static let grabberHeight: CGFloat = 4

    /// Tab bar and bottom bars sit on paper at 96%.
    static let barOpacity: Double = 0.96
    /// The scrim behind a modal sheet.
    static let scrimOpacity: Double = 0.4
}
