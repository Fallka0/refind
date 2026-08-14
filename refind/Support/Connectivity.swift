//
//  Connectivity.swift
//  refind
//
//  The offline banner the handoff lists alongside loading, empty and error.
//  Driven by the real network path rather than by a failed request, so it is
//  right even before anything has been asked for.
//

import SwiftUI
import Network

@MainActor
@Observable
final class ConnectivityMonitor {
    private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "refind.connectivity")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}

struct OfflineBanner: View {
    var body: some View {
        Text("Keine Verbindung")
            .rfLabel(10, color: RF.Palette.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RF.Palette.ink)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
    }
}
