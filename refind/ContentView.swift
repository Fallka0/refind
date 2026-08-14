//
//  ContentView.swift
//  refind
//
//  The tab shell. Splash and onboarding gate this in step 9.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if DEBUG
        if let screen = DebugScreen.requested {
            DebugScreenHost(screen: screen)
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment.preview)
}
