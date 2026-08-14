//
//  DTOs.swift
//  refind
//
//  Wire shapes from docs/API.md, kept separate from the domain models on
//  purpose: the server's JSON can change without dragging every screen with it.
//

import Foundation

// MARK: - Primitives

struct MoneyDTO: Codable, Sendable {
    let minorUnits: Int
    let currency: String

    var domain: Money { Money(minorUnits: minorUnits) }

    init(_ money: Money) {
        self.minorUnits = money.minorUnits
        self.currency = "CHF"
    }
}

struct PageDTO<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let nextCursor: String?
}

// MARK: - User

struct UserDTO: Codable, Sendable {
    let id: String
    let displayName: String
    let city: String
    let memberSince: Date
    let rating: Double
    let dealCount: Int
    let verified: Bool
    let avatarURL: URL?

    var domain: User {
        User(id: id, displayName: displayName, city: city, memberSince: memberSince,
             rating: rating, dealCount: dealCount, verified: verified)
    }
}

struct StatsDTO: Decodable, Sendable {
    let rating: Double
    let dealCount: Int
    let liveWantCount: Int

    var domain: ProfileStats {
        ProfileStats(rating: rating, dealCount: dealCount, liveWantCount: liveWantCount)
    }
}

// MARK: - Want

struct WantDTO: Decodable, Sendable {
    let id: String
    let ownerId: String
    let title: String
    let category: String
    let budgetMax: MoneyDTO
    let condition: String
    let region: String
    let radiusKm: Int
    let description: String?
    let createdAt: Date
    let expiresAt: Date
    let status: String
    let offerCount: Int
    let unreadOfferCount: Int

    var domain: Want {
        Want(id: id, ownerID: ownerId, title: title,
             category: Category(rawValue: category) ?? .uhren,
             budgetMax: budgetMax.domain,
             condition: Condition(rawValue: condition) ?? .any,
             region: region, radiusKm: radiusKm, itemDescription: description,
             createdAt: createdAt, expiresAt: expiresAt,
             status: Want.Status(rawValue: status) ?? .live,
             offerCount: offerCount, unreadOfferCount: unreadOfferCount)
    }
}

struct WantDraftDTO: Encodable, Sendable {
    let title: String
    let category: String
    let budgetMax: MoneyDTO
    let condition: String
    let region: String
    let radiusKm: Int
    let durationDays: Int

    init(_ draft: WantDraft) {
        title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        category = draft.category.rawValue
        budgetMax = MoneyDTO(draft.budgetMax)
        condition = draft.condition.rawValue
        region = draft.region
        radiusKm = draft.radiusKm
        durationDays = draft.durationDays
    }
}

// MARK: - Offer

struct PhotoDTO: Codable, Sendable {
    let id: String
    let url: URL?

    var domain: PhotoRef { PhotoRef(id: id, url: url) }
}

struct OfferDTO: Decodable, Sendable {
    let id: String
    let wantId: String
    let seller: UserDTO
    let price: MoneyDTO
    let message: String
    let photos: [PhotoDTO]
    let createdAt: Date
    let status: String

    var domain: Offer {
        Offer(id: id, wantID: wantId, seller: seller.domain, price: price.domain,
              message: message, photos: photos.map(\.domain), createdAt: createdAt,
              status: Offer.Status(rawValue: status) ?? .sent)
    }
}

struct OfferDraftDTO: Encodable, Sendable {
    let price: MoneyDTO
    let message: String
    let photoIds: [String]

    init(_ draft: OfferDraft) {
        price = MoneyDTO(draft.price)
        message = draft.message
        photoIds = draft.photos.map(\.id)
    }
}

// MARK: - Chat

struct ThreadDTO: Decodable, Sendable {
    let id: String
    let offerId: String
    let wantId: String
    let wantTitle: String
    let offerPrice: MoneyDTO
    let partner: UserDTO
    let lastMessage: String
    let lastMessageWasMine: Bool
    let lastActivity: Date
    let unreadCount: Int

    var domain: ChatThread {
        ChatThread(id: id, offerID: offerId, wantID: wantId, wantTitle: wantTitle,
                   offerPrice: offerPrice.domain, partner: partner.domain,
                   lastMessage: lastMessage, lastMessageWasMine: lastMessageWasMine,
                   lastActivity: lastActivity, unreadCount: unreadCount)
    }
}

struct MessageDTO: Decodable, Sendable {
    let id: String
    let threadId: String
    let senderId: String
    let kind: String
    let body: String
    let photo: PhotoDTO?
    let createdAt: Date
    let readAt: Date?

    var domain: Message {
        let resolved: Message.Kind
        switch kind {
        case "photo":  resolved = photo.map { .photo($0.domain) } ?? .text
        case "system": resolved = .system
        default:       resolved = .text
        }
        return Message(id: id, threadID: threadId, senderID: senderId, kind: resolved,
                       body: body, createdAt: createdAt, readAt: readAt)
    }
}

/// One frame of `/threads/{id}/socket`.
struct ThreadEventDTO: Decodable, Sendable {
    let type: String
    let userId: String?
    let isTyping: Bool?
    let message: MessageDTO?
}

// MARK: - Deal and escrow

struct DealDTO: Decodable, Sendable {
    let id: String
    let offerId: String
    let threadId: String
    let wantTitle: String
    let partner: UserDTO
    let finalPrice: MoneyDTO
    let handoverAt: Date
    let handoverPlace: String
    let ratedByBuyer: Bool
    let ratedBySeller: Bool

    var domain: Deal {
        Deal(id: id, offerID: offerId, threadID: threadId, wantTitle: wantTitle,
             partner: partner.domain, finalPrice: finalPrice.domain,
             handoverAt: handoverAt, handoverPlace: handoverPlace,
             ratedByBuyer: ratedByBuyer, ratedBySeller: ratedBySeller)
    }
}

struct EscrowDTO: Decodable, Sendable {
    let id: String
    let dealId: String
    let method: String
    let amount: MoneyDTO
    let fee: MoneyDTO
    let receiptNumber: String
    let paidAt: Date
    let stage: String
    let autoRefundAt: Date?

    var domain: Escrow {
        Escrow(id: id, dealID: dealId,
               method: PaymentMethod(rawValue: method) ?? .escrow,
               amount: amount.domain,
               // The server's fee wins: the client's estimate is for composing
               // only, and a receipt must not disagree with the ledger.
               fee: fee.domain,
               receiptNumber: receiptNumber, paidAt: paidAt,
               stage: Escrow.Stage(wire: stage))
    }
}

extension Escrow.Stage {
    init(wire: String) {
        switch wire {
        case "handover":            self = .handover
        case "released", "refunded": self = .released
        default:                    self = .paid
        }
    }
}

// MARK: - Safety and verification

struct ReportDTO: Encodable, Sendable {
    let subjectType: String
    let subjectId: String
    let reason: String
    let detail: String
}

struct VerificationDTO: Decodable, Sendable {
    let status: String
    let reason: String?

    var domain: VerificationStatus { VerificationStatus(rawValue: status) ?? .unverified }
}
