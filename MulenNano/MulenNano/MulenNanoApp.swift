//
//  MulenNanoApp.swift
//  MulenNano
//
//  Nativní macOS aplikace pro tvorbu a úpravu obrázků pomocí AI.
//  Design: bright, restrained workspace inspired by Photos for macOS.
//

import SwiftUI

@main
struct MulenNanoApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(env)
        }
    }
}
