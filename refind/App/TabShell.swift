//
//  TabShell.swift
//  refind
//
//  A real TabView so each tab keeps its own navigation stack, with the system
//  bar hidden and RFTabBar in its place.
//

import SwiftUI

struct TabShell: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: AppTab = .gesuche
    @State private var chatUnread = 0
    @State private var connectivity = ConnectivityMonitor()

    var body: some View {
        // The bar is a sibling, not a safeAreaInset on the TabView: an inset
        // there is not forwarded into the   content, so a screen's own bottom
        // inset (Home's "Gesuch aufhängen") ended up underneath the bar.
        VStack(spacing: 0) {
            if !connectivity.isOnline {
                OfflineBanner()
            }
            TabView(selection: $selection) {
                ForEach(AppTab.allCases) { tab in
                    content(for: tab)
                        .tag(tab)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            RFTabBar(selection: $selection, chatUnread: chatUnread)
        }
        .background(RF.Palette.paper)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(RF.Motion.entrance, value: connectivity.isOnline)
        .task(id: selection) { await refreshUnread() }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        NavigationStack {
            switch tab {
            case .gesuche:   HomeScreen()
            case .entdecken: DiscoverScreen()
            case .chat:      ChatsScreen()
            case .profil:    ProfileScreen()
            }
        }
    }

    private func refreshUnread() async {
        let threads = try? await environment.repository.threads()
        chatUnread = threads?.reduce(0) { $0 + $1.unreadCount } ?? 0
    }
}

#Preview("Tab shell") {
    TabShell()
        .environment(AppEnvironment.preview)
}
