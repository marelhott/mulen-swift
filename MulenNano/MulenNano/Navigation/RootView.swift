//
//  RootView.swift
//  MulenNano
//
//  macOS 26 Liquid Glass layout:
//  Průhledné okno (desktop vibrancy) + úzký icon sidebar + zaoblený glass panel pro obsah.
//

import SwiftUI

struct RootView: View {
    @State private var selection: SidebarItem = .generate

    var body: some View {
        HStack(spacing: 0) {
            // Úzký icon sidebar — floatuje nad desktop vibrancy, bez vlastního pozadí
            GlassIconSidebar(selection: $selection)
                .frame(width: 64)

            // Hlavní glass panel — macOS 26 .glassEffect() sampuluje wallpaper za oknem
            contentView(for: selection)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 8)
                .padding(.bottom, 8)
                .padding(.trailing, 8)
        }
        .frame(minWidth: 920, minHeight: 600)
        .ignoresSafeArea()
        // Desktop vibrancy jako pozadí celého okna
        .background {
            DesktopVibrancyBackground()
                .ignoresSafeArea()
        }
        // Nastaví NSWindow průhledným
        .background(WindowTransparency())
    }

    @ViewBuilder
    private func contentView(for item: SidebarItem) -> some View {
        switch item {
        case .generate:        GenerateView()
        case .upscaler:        UpscalerView()
        case .faceSwap:        FaceSwapView()
        case .reframe:         ReframeView()
        case .batch:           BatchView()
        case .all:             LibraryView()
        case .collections:     CollectionsView()
        case .recentlyDeleted: TrashView()
        }
    }
}

// MARK: - Icon Sidebar

struct GlassIconSidebar: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(spacing: 0) {
            // Prostor pro traffic lights (hiddenTitleBar je renderuje automaticky vlevo nahoře)
            Color.clear.frame(height: 48)

            VStack(spacing: 2) {
                ForEach(SidebarItem.tools) { item in
                    iconButton(item)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 2) {
                ForEach(SidebarItem.library) { item in
                    iconButton(item)
                }
            }
            .padding(.horizontal, 8)

            // Nastavení
            Divider()
                .opacity(0.3)
                .padding(.vertical, 8)

            SettingsLink {
                iconShape("gearshape", active: false)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            Color.clear.frame(height: 14)
        }
    }

    private func iconButton(_ item: SidebarItem) -> some View {
        Button { selection = item } label: {
            iconShape(item.systemImage, active: selection == item)
        }
        .buttonStyle(.plain)
        .help(item.title)
    }

    private func iconShape(_ name: String, active: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: active ? .semibold : .regular))
            .frame(width: 44, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.55))
            .contentShape(Rectangle())
    }
}

#Preview {
    RootView()
        .frame(width: 1200, height: 780)
}
