//
//  ChatThread.swift
//  refind
//
//  A thread always hangs off an offer — the context line naming the want and
//  the price is what separates a refind chat from a generic DM.
//

import Foundation

struct ChatThread: Identifiable, Hashable, Sendable {
    let id: String
    let offerID: String
    let wantID: String
    let wantTitle: String
    let offerPrice: Money
    let partner: User
    let lastMessage: String
    let lastMessageWasMine: Bool
    let lastActivity: Date
    let unreadCount: Int

    var isUnread: Bool { unreadCount > 0 }

    /// "OMEGA SEAMASTER · CHF 1'720" — rendered as a label (caps + tracking).
    var contextLine: String { "\(wantTitle) · \(offerPrice.formatted)" }

    /// "Du: Danke, ich überlege es mir."
    var lastMessagePreview: String {
        lastMessageWasMine ? "Du: \(lastMessage)" : lastMessage
    }
}

struct Message: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case text
        case photo(PhotoRef)
        /// The centred chip that opens every thread.
        case system
    }

    let id: String
    let threadID: String
    let senderID: String
    let kind: Kind
    let body: String
    let createdAt: Date
    var readAt: Date?

    func isMine(currentUserID: String) -> Bool { senderID == currentUserID }
}

/// What the other side is doing right now — the mock drives the typing dots with this.
enum PartnerActivity: Hashable, Sendable {
    case idle
    case typing
}
