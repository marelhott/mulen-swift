//
//  RootView.swift
//  MulenNano
//
//  Opaque, quiet layout inspired by Photos for macOS.
//

import SwiftUI

struct RootView: View {
    @State private var selection: SidebarItem = .generate

    var body: some View {
        HStack(spacing: 0) {
            GlassSidebar(selection: $selection)
                .frame(width: 184)
                .background(Color(red: 0.957, green: 0.957, blue: 0.969))

            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(width: 1)

            contentView(for: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
        }
        .frame(minWidth: 920, minHeight: 600)
        .ignoresSafeArea()
        .background(Color.white)
        .background(PhotosWindowConfiguration())
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.22), lineWidth: 1)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .font(.dsStandard)
        .tracking(0)
        .lineSpacing(0)
        .environment(\.colorScheme, .light)
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

// MARK: - Sidebar

struct GlassSidebar: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 50)

            navigationSection("Nástroje", items: SidebarItem.tools)

            Spacer()

            navigationSection("Knihovna", items: SidebarItem.library)

            Divider()
                .opacity(0.22)
                .padding(.vertical, 8)

            SettingsLink {
                sidebarLabel(title: "Nastavení", systemImage: "gearshape", active: false)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)

            Color.clear.frame(height: 12)
        }
    }

    private func navigationSection(_ title: String, items: [SidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.dsSmallSemibold)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 3)

            ForEach(items) { item in
                sidebarButton(item)
            }
        }
        .padding(.horizontal, 10)
    }

    private func sidebarButton(_ item: SidebarItem) -> some View {
        Button { selection = item } label: {
            sidebarLabel(title: item.title, systemImage: item.systemImage, active: selection == item)
        }
        .buttonStyle(.plain)
    }

    private func sidebarLabel(title: String, systemImage: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: active ? .semibold : .regular))
                .frame(width: 16)
            Text(title)
                .font(active ? .dsStandardMedium : .dsStandard)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background {
            if active {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.13))
            }
        }
        .foregroundStyle(active ? Color.primary : Color.secondary)
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

#Preview {
    RootView()
        .frame(width: 1200, height: 780)
}
