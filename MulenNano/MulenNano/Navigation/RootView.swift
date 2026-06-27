//
//  RootView.swift
//  MulenNano
//
//  macOS 26 Liquid Glass layout:
//  průhledné okno → icon sidebar + skleněný hlavní panel nad desktopem.
//

import SwiftUI

struct RootView: View {
    @State private var selection: SidebarItem = .generate

    var body: some View {
        HStack(spacing: 0) {
            // Úzký icon sidebar
            GlassIconSidebar(selection: $selection)
                .frame(width: 62)

            // Hlavní glass panel
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)

                contentView(for: selection)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 6)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .padding(.trailing, 8)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(.clear)
        .background(WindowGlassBackground())
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func contentView(for item: SidebarItem) -> some View {
        switch item {
        case .generate:     GenerateView()
        case .upscaler:     UpscalerView()
        case .faceSwap:     FaceSwapView()
        case .reframe:      ReframeView()
        case .batch:        BatchView()
        case .all:          LibraryView()
        case .collections:  CollectionsView()
        case .recentlyDeleted: TrashView()
        }
    }
}

// MARK: - Icon Sidebar

struct GlassIconSidebar: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(spacing: 0) {
            // Místo pro traffic lights (hiddenTitleBar je renderuje automaticky vlevo nahoře)
            Spacer().frame(height: 52)

            // Nástroje
            VStack(spacing: 2) {
                ForEach(SidebarItem.tools) { iconBtn($0) }
            }

            Spacer()

            // Knihovna
            VStack(spacing: 2) {
                ForEach(SidebarItem.library) { iconBtn($0) }
            }

            Divider()
                .padding(.vertical, DS.Space.s)

            // Nastavení
            SettingsLink {
                sidebarIcon("gearshape", active: false)
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 16)
        }
        .padding(.horizontal, 6)
    }

    private func iconBtn(_ item: SidebarItem) -> some View {
        Button { selection = item } label: {
            sidebarIcon(item.systemImage, active: selection == item)
        }
        .buttonStyle(.plain)
        .help(item.title)
    }

    private func sidebarIcon(_ name: String, active: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: active ? .semibold : .regular))
            .frame(width: 42, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .foregroundStyle(active ? Color.accentColor : Color.secondary)
            .contentShape(Rectangle())
    }
}

#Preview {
    RootView()
        .frame(width: 1200, height: 780)
}
