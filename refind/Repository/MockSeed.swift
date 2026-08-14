//
//  MockSeed.swift
//  refind
//
//  Every string, price and timestamp here is lifted from the design mocks.
//  Dates are relative to launch so "VOR 12 MIN" and "2 TAGE" stay true.
//
//  One invention, flagged: the Omega want's header says "4 ANGEBOTE" but the
//  mock draws three offer rows. `businger` is the fourth, priced to sit between
//  Marc and Lena so the price-ascending sort still leads with Marc's card.
//

import Foundation

enum MockSeed {

    // MARK: Time base

    static let now = Date()
    static func minutesAgo(_ m: Int) -> Date { now.addingTimeInterval(-Double(m) * 60) }
    static func hoursAgo(_ h: Int) -> Date { now.addingTimeInterval(-Double(h) * 3600) }
    static func daysAgo(_ d: Int) -> Date { now.addingTimeInterval(-Double(d) * 86_400) }
    static func daysAhead(_ d: Int) -> Date { now.addingTimeInterval(Double(d) * 86_400) }

    // MARK: People

    static let me = User(
        id: "u-jan",
        displayName: "Jan Roth",
        city: "Zürich",
        memberSince: Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: 2026, month: 1, day: 9)) ?? now,
        rating: 4.8,
        dealCount: 11,
        verified: false
    )

    static let marc = User(id: "u-marc", displayName: "Marc B.", city: "Zürich",
                           memberSince: daysAgo(880), rating: 4.9, dealCount: 23, verified: true)
    static let lena = User(id: "u-lena", displayName: "Lena W.", city: "Winterthur",
                           memberSince: daysAgo(420), rating: 4.7, dealCount: 8, verified: true)
    static let furrer = User(id: "u-furrer", displayName: "R. Furrer", city: "Bern",
                             memberSince: daysAgo(300), rating: 4.5, dealCount: 3, verified: false)
    static let businger = User(id: "u-businger", displayName: "T. Businger", city: "Luzern",
                               memberSince: daysAgo(210), rating: 4.6, dealCount: 5, verified: false)
    static let nina = User(id: "u-nina", displayName: "Nina T.", city: "Zürich",
                           memberSince: daysAgo(640), rating: 4.9, dealCount: 17, verified: true)
    static let samuel = User(id: "u-samuel", displayName: "Samuel K.", city: "Basel",
                             memberSince: daysAgo(150), rating: 4.4, dealCount: 2, verified: false)

    static let people: [User] = [me, marc, lena, furrer, businger, nina, samuel]

    // MARK: My wants (screen 03)

    static let omegaWant = Want(
        id: "w-omega",
        ownerID: me.id,
        title: "Omega Seamaster 166.062",
        category: .uhren,
        budgetMax: Money(chf: 2_000),
        condition: .original,
        region: "Zürich",
        radiusKm: 30,
        itemDescription: "Suche Originalzustand, gerne mit Papieren. Zustand vor Preis.",
        createdAt: daysAgo(3),
        expiresAt: daysAhead(11),
        status: .live,
        offerCount: 4,
        unreadOfferCount: 4
    )

    static let usmWant = Want(
        id: "w-usm",
        ownerID: me.id,
        title: "USM Haller, 3 Fächer",
        category: .moebel,
        budgetMax: Money(chf: 900),
        condition: .any,
        region: "Zürich",
        radiusKm: 30,
        itemDescription: nil,
        createdAt: daysAgo(12),
        expiresAt: daysAhead(2),
        status: .live,
        offerCount: 1,
        unreadOfferCount: 0
    )

    static let veloWant = Want(
        id: "w-velo",
        ownerID: me.id,
        title: "Rennvelo Gr. 56",
        category: .velo,
        budgetMax: Money(chf: 1_200),
        condition: .any,
        region: "Zürich",
        radiusKm: 30,
        itemDescription: nil,
        createdAt: daysAgo(40),
        expiresAt: daysAgo(4),
        status: .expired,
        offerCount: 0,
        unreadOfferCount: 0
    )

    static let myWants: [Want] = [omegaWant, usmWant, veloWant]

    // MARK: Other people's wants (screen 08)

    static let eamesWant = Want(
        id: "w-eames",
        ownerID: nina.id,
        title: "Eames Lounge Chair, Nussbaum",
        category: .moebel,
        budgetMax: Money(chf: 4_500),
        condition: .any,
        region: "Zürich",
        radiusKm: 30,
        itemDescription: "Original oder Vitra-Lizenz. Kleine Patina ist okay, keine Risse im Leder.",
        createdAt: minutesAgo(20),
        expiresAt: daysAhead(13),
        status: .live,
        offerCount: 2,
        unreadOfferCount: 0
    )

    static let leicaWant = Want(
        id: "w-leica",
        ownerID: samuel.id,
        title: "Leica M6, funktionierender Belichtungsmesser",
        category: .kameras,
        budgetMax: Money(chf: 3_000),
        condition: .serviced,
        region: "Basel",
        radiusKm: 50,
        itemDescription: nil,
        createdAt: hoursAgo(2),
        expiresAt: daysAhead(9),
        status: .live,
        offerCount: 0,
        unreadOfferCount: 0
    )

    static let discoverWants: [Want] = [eamesWant, leicaWant]

    static let allWants: [Want] = myWants + discoverWants

    // MARK: Offers on the Omega (screen 07)

    static let offers: [Offer] = [
        Offer(id: "o-marc", wantID: omegaWant.id, seller: marc,
              price: Money(chf: 1_720),
              message: "166.062, Service 2024, mit Box und Papieren.",
              photos: [PhotoRef(id: "p-marc-1"), PhotoRef(id: "p-marc-2")],
              createdAt: minutesAgo(12), status: .sent),

        Offer(id: "o-businger", wantID: omegaWant.id, seller: businger,
              price: Money(chf: 1_890),
              message: "Ehrliche Patina, läuft gut. Kein Service-Beleg.",
              photos: [PhotoRef(id: "p-businger-1")],
              createdAt: hoursAgo(5), status: .sent),

        Offer(id: "o-lena", wantID: omegaWant.id, seller: lena,
              price: Money(chf: 1_950),
              message: "Aus Sammlungsauflösung, ungetragen seit Service.",
              photos: [PhotoRef(id: "p-lena-1")],
              createdAt: hoursAgo(1), status: .sent),

        Offer(id: "o-furrer", wantID: omegaWant.id, seller: furrer,
              price: Money(chf: 2_100),
              message: "Sammlerstück, Preis ist knapp verhandelbar.",
              photos: [PhotoRef(id: "p-furrer-1")],
              createdAt: hoursAgo(3), status: .sent),

        Offer(id: "o-usm", wantID: usmWant.id, seller: lena,
              price: Money(chf: 850),
              message: "Drei Fächer, reinweiss, kleine Kratzer hinten.",
              photos: [PhotoRef(id: "p-usm-1")],
              createdAt: daysAgo(1), status: .sent),

        // My own offer on Nina's Eames — the thread on screen 10 hangs off this.
        Offer(id: "o-eames", wantID: eamesWant.id, seller: me,
              price: Money(chf: 4_200),
              message: "Nussbaum, Vitra 2009, Leder ohne Risse. Abholung in Winterthur.",
              photos: [PhotoRef(id: "p-eames-1"), PhotoRef(id: "p-eames-2")],
              createdAt: daysAgo(6), status: .accepted)
    ]

    // MARK: Threads (screen 10)

    static let threads: [ChatThread] = [
        ChatThread(id: "t-marc", offerID: "o-marc", wantID: omegaWant.id,
                   wantTitle: "Omega Seamaster", offerPrice: Money(chf: 1_720),
                   partner: marc,
                   lastMessage: "Werkfoto ist unterwegs, gib mir 5 Min.",
                   lastMessageWasMine: false,
                   lastActivity: minutesAgo(9), unreadCount: 2),

        ChatThread(id: "t-lena", offerID: "o-lena", wantID: omegaWant.id,
                   wantTitle: "Omega Seamaster", offerPrice: Money(chf: 1_950),
                   partner: lena,
                   lastMessage: "Danke, ich überlege es mir.",
                   lastMessageWasMine: true,
                   lastActivity: daysAgo(1), unreadCount: 0),

        ChatThread(id: "t-nina", offerID: "o-eames", wantID: eamesWant.id,
                   wantTitle: "Eames Lounge", offerPrice: Money(chf: 4_200),
                   partner: nina,
                   lastMessage: "Angebot angenommen · Abholung Sa",
                   lastMessageWasMine: false,
                   lastActivity: daysAgo(4), unreadCount: 0)
    ]

    // MARK: Messages (screen 11)

    static let messages: [String: [Message]] = [
        "t-marc": [
            Message(id: "m-1", threadID: "t-marc", senderID: "system", kind: .system,
                    body: "ANGEBOT AUF «OMEGA SEAMASTER 166.062»",
                    createdAt: hoursAgo(2), readAt: hoursAgo(2)),
            Message(id: "m-2", threadID: "t-marc", senderID: marc.id,
                    kind: .photo(PhotoRef(id: "p-werk")),
                    body: "", createdAt: minutesAgo(26), readAt: minutesAgo(25)),
            Message(id: "m-3", threadID: "t-marc", senderID: me.id, kind: .text,
                    body: "Sieht gut aus. Gehen 1\u{2019}600 mit Übergabe in Zürich?",
                    createdAt: minutesAgo(22), readAt: minutesAgo(21)),
            Message(id: "m-4", threadID: "t-marc", senderID: marc.id, kind: .text,
                    body: "1\u{2019}650 und ich bringe sie vorbei.",
                    createdAt: minutesAgo(14), readAt: nil),
            Message(id: "m-5", threadID: "t-marc", senderID: marc.id, kind: .text,
                    body: "Werkfoto ist unterwegs, gib mir 5 Min.",
                    createdAt: minutesAgo(9), readAt: nil)
        ],
        "t-lena": [
            Message(id: "m-l1", threadID: "t-lena", senderID: "system", kind: .system,
                    body: "ANGEBOT AUF «OMEGA SEAMASTER 166.062»",
                    createdAt: daysAgo(2), readAt: daysAgo(2)),
            Message(id: "m-l2", threadID: "t-lena", senderID: lena.id, kind: .text,
                    body: "Hätte sie in Originalzustand, Service letztes Jahr.",
                    createdAt: daysAgo(2), readAt: daysAgo(2)),
            Message(id: "m-l3", threadID: "t-lena", senderID: me.id, kind: .text,
                    body: "Danke, ich überlege es mir.",
                    createdAt: daysAgo(1), readAt: daysAgo(1))
        ],
        "t-nina": [
            Message(id: "m-n1", threadID: "t-nina", senderID: "system", kind: .system,
                    body: "ANGEBOT AUF «EAMES LOUNGE CHAIR, NUSSBAUM»",
                    createdAt: daysAgo(6), readAt: daysAgo(6)),
            Message(id: "m-n2", threadID: "t-nina", senderID: nina.id, kind: .text,
                    body: "Angebot angenommen · Abholung Sa",
                    createdAt: daysAgo(4), readAt: daysAgo(4))
        ]
    ]

    // MARK: Deal and escrow (screens 12, 14–18)

    static let marcDeal = Deal(
        id: "d-marc",
        offerID: "o-marc",
        threadID: "t-marc",
        wantTitle: "Omega Seamaster 166.062",
        partner: marc,
        finalPrice: Money(chf: 1_650),
        handoverAt: nextSaturdayAtTwo,
        handoverPlace: "Zürich HB",
        ratedByBuyer: false,
        ratedBySeller: false
    )

    /// The designs say "SA, 14:00" — resolve to the next Saturday so the stamp
    /// stays honest whenever the app is run.
    static var nextSaturdayAtTwo: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = RF.locale
        let next = cal.nextDate(after: now,
                               matching: DateComponents(hour: 14, minute: 0, weekday: 7),
                               matchingPolicy: .nextTime) ?? now.addingTimeInterval(86_400)
        return next
    }

    static let receiptNumber = "RF-2026-0114"

    // MARK: Typeahead (screen 04)

    static let titleCatalog: [String] = [
        "Omega Seamaster 300",
        "Omega Seamaster De Ville",
        "Omega Speedmaster",
        "Omega Constellation",
        "USM Haller Sideboard",
        "USM Haller Rollcontainer",
        "Eames Lounge Chair",
        "Eames Plastic Chair",
        "Leica M6",
        "Leica M-A",
        "Rennvelo Stahlrahmen",
        "Vitra Aluminium Chair"
    ]

    // MARK: Onboarding

    static let onboardingCategories: [Category] = Category.allCases
}
