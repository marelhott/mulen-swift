//
//  MulenNanoApp.swift
//  MulenNano
//
//  Nativní macOS aplikace pro tvorbu a úpravu obrázků pomocí AI.
//  Design: macOS 26 Liquid Glass — průhledné okno, glass panely, desktop probíjí.
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
