//
//  User.swift
//  refind
//

import Foundation

struct User: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let city: String
    let memberSince: Date
    let rating: Double
    let dealCount: Int
    let verified: Bool

    /// The mocks show no photos for people — the avatar is the initial in the
    /// brand serif on an ink circle.
    var initial: String { String(displayName.prefix(1)) }

    /// "4.9 · 23 DEALS" — the trust line under a name.
    var trustLine: String {
        "\(RF.rating(rating)) · \(dealCount) DEALS"
    }
}

struct ProfileStats: Hashable, Sendable {
    let rating: Double
    let dealCount: Int
    let liveWantCount: Int
}
