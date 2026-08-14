//
//  PushNotifications.swift
//  refind
//
//  The push copy set the handoff lists as undecided, plus registration.
//
//  Copy lives in the app, not the payload: the server sends `loc-key` and
//  `loc-args` (see docs/API.md), so wording and language are the client's to
//  change without a deploy. These are the German source strings for those keys.
//

import Foundation
import UserNotifications
import UIKit

enum PushKind: String, CaseIterable, Sendable {
    case offerReceived   = "push.offer.received"
    case offerAccepted   = "push.offer.accepted"
    case offerDeclined   = "push.offer.declined"
    case messageReceived = "push.message.received"
    case dealConfirmed   = "push.deal.confirmed"
    case escrowPaid      = "push.escrow.paid"
    case escrowReleased  = "push.escrow.released"
    case handoverToday   = "push.handover.today"
    case wantExpiring    = "push.want.expiring"
    case wantExpired     = "push.want.expired"

    /// Titles stay short — a notification is read at a glance, not studied.
    var title: String {
        switch self {
        case .offerReceived:   return String(localized: "Neues Angebot")
        case .offerAccepted:   return String(localized: "Angebot angenommen")
        case .offerDeclined:   return String(localized: "Angebot abgelehnt")
        case .messageReceived: return String(localized: "Neue Nachricht")
        case .dealConfirmed:   return String(localized: "Deal steht")
        case .escrowPaid:      return String(localized: "Geld ist sicher")
        case .escrowReleased:  return String(localized: "Geld freigegeben")
        case .handoverToday:   return String(localized: "Übergabe heute")
        case .wantExpiring:    return String(localized: "Gesuch läuft aus")
        case .wantExpired:     return String(localized: "Gesuch abgelaufen")
        }
    }

    /// `args` maps to the payload's `loc-args`, in order.
    func body(_ args: [String]) -> String {
        func arg(_ i: Int) -> String { i < args.count ? args[i] : "" }
        switch self {
        case .offerReceived:
            return "\(arg(0)) bietet \(arg(1)) für «\(arg(2))»."
        case .offerAccepted:
            return "\(arg(0)) nimmt dein Angebot für «\(arg(1))» an."
        case .offerDeclined:
            return "Für «\(arg(0))» hat sich jemand anderes gefunden."
        case .messageReceived:
            return "\(arg(0)): \(arg(1))"
        case .dealConfirmed:
            return "\(arg(0)) · \(arg(1)). Details stehen im Chat."
        case .escrowPaid:
            return "\(arg(0)) hat bezahlt. Die Übergabe kann stattfinden."
        case .escrowReleased:
            return "\(arg(0)) ist unterwegs zu dir."
        case .handoverToday:
            return "\(arg(0)) mit \(arg(1)), \(arg(2))."
        case .wantExpiring:
            return "«\(arg(0))» läuft in \(arg(1)) aus. Verlängern?"
        case .wantExpired:
            return "«\(arg(0))» ist abgelaufen. Nochmal aufhängen?"
        }
    }
}

@MainActor
@Observable
final class PushRegistrar: NSObject {

    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var deviceToken: String?

    private let repository: any RefindRepository

    init(repository: any RefindRepository) {
        self.repository = repository
        super.init()
    }

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus
    }

    /// Onboarding step 3 and the Benachrichtigungen row both land here.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        await refreshAuthorization()
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }

    /// Called by the app delegate once APNs hands back a token.
    func handle(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        Task {
            #if DEBUG
            let sandbox = true
            #else
            let sandbox = false
            #endif
            try? await repository.registerDevice(token: token, sandbox: sandbox)
        }
    }
}

/// APNs still reports back through UIKit, so the app needs a delegate even in a
/// SwiftUI lifecycle.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static weak var registrar: PushRegistrar?

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Task { @MainActor in Self.registrar?.handle(deviceToken: token) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Nothing to show the user — push is a nicety, not a blocker.
    }
}
