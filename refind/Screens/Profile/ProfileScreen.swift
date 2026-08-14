//
//  ProfileScreen.swift
//  refind
//
//  Screen 13 · Profil (tab 4)
//

import SwiftUI

struct ProfileScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var stats: ProfileStats?
    @State private var user: User?
    @State private var route: ProfileRoute?
    @AppStorage("rf.searchRadiusKm") private var radiusKm = 30

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    statsRow.padding(.horizontal, RF.Metric.screenMargin)
                    settings.padding(.top, 26)
                    upsell.padding(.top, 22)
                        .padding(.horizontal, RF.Metric.screenMargin)
                    Spacer(minLength: 30)
                }
                .padding(.top, RF.Metric.topInsetTabbed)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            user = try? await environment.repository.currentUser()
            stats = try? await environment.repository.profileStats()
        }
        .sheet(item: $route) { route in
            ProfileSheet(route: route, radiusKm: $radiusKm)
                .environment(environment)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 16) {
            RFAvatar(initial: (user ?? MockSeed.me).initial,
                     style: .photo(seed: "avatar-\((user ?? MockSeed.me).id)"),
                     size: RF.Metric.avatarProfile)
            VStack(alignment: .leading, spacing: 5) {
                Text((user ?? MockSeed.me).displayName)
                    .font(RF.display(30))
                    .foregroundStyle(RF.Palette.ink)
                Text("\((user ?? MockSeed.me).city.uppercased()) · \(RF.memberSince((user ?? MockSeed.me).memberSince))")
                    .rfLabel(11, tracking: 0.66)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, RF.Metric.screenMargin)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(RF.rating(stats?.rating ?? MockSeed.me.rating), "Bewertung")
            statCard("\(stats?.dealCount ?? MockSeed.me.dealCount)", "Deals")
            statCard("\(stats?.liveWantCount ?? 0)", "Live")
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        RFCard(padding: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(RF.num(22, weight: .medium))
                    .foregroundStyle(RF.Palette.ink)
                Text(label).rfLabel(9, tracking: 0.72)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Konto").rfLabel(10).padding(.bottom, 6)
            row("Zahlungsarten") { route = .payment }
            row("Benachrichtigungen") { route = .notifications }
            row("Suchradius", value: "\(radiusKm) km") { route = .radius }
            row("Verifizierung",
                value: environment.verification.displayName,
                valueColor: environment.verification.isAttention
                    ? RF.Palette.offer : RF.Palette.muted) {
                route = .verification
            }
            row("Blockiert") { route = .blocked }
        }
        .padding(.horizontal, RF.Metric.screenMargin)
    }

    private func row(_ title: String,
                     value: String? = nil,
                     valueColor: Color = RF.Palette.muted,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(RF.ui(15))
                    .foregroundStyle(RF.Palette.ink)
                Spacer()
                if let value {
                    Text(value)
                        .font(RF.ui(15))
                        .foregroundStyle(valueColor)
                }
                Text("›")
                    .font(RF.ui(15))
                    .foregroundStyle(RF.Palette.muted)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RF.Palette.line).frame(height: RF.Metric.hairline)
        }
    }

    /// The one Fin on this screen.
    private var upsell: some View {
        RFCard(padding: 16) {
            HStack(spacing: 14) {
                FinMascot(state: .asking, height: 40)
                Text("Verifiziertes Profil? Deine Gesuche bekommen rund 40 % mehr Angebote.")
                    .font(RF.ui(13))
                    .foregroundStyle(RF.Palette.inkMid)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview("13 Profil") {
    ProfileScreen().environment(AppEnvironment.preview)
}
