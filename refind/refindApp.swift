//
//  refindApp.swift
//  refind
//
//  Created by Mykyta Pantelei on 14.08.2026.
//

import SwiftUI

@main
struct refindApp: App {
    @State private var environment = AppEnvironment()

    init() {
        FontLoader.verify()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .task { await environment.loadSession() }
        }
    }
}
