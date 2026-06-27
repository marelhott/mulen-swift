//
//  SidebarView.swift
//  MulenNano
//
//  Vibrancy sidebar (navigační vrstva). Nastavení naplocho dole — bez pozadí, bez stínu.
//

import SwiftUI

// SidebarView zůstává pro zpětnou kompatibilitu, ale v RootView ho nahrazuje GlassIconSidebar.
struct SidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Nástroje") {
                    ForEach(SidebarItem.tools) { row($0) }
                }
                Section("Knihovna") {
                    ForEach(SidebarItem.library) { row($0) }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            settingsRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
    }

    private func row(_ item: SidebarItem) -> some View {
        Label(item.title, systemImage: item.systemImage)
            .tag(item)
    }

    private var settingsRow: some View {
        SettingsLink {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .regular))
                Text("Nastavení")
                    .font(.dsLabel)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, DS.Space.xs)
    }
}
