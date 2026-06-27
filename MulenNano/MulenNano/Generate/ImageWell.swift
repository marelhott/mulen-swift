//
//  ImageWell.swift
//  MulenNano
//
//  Kompaktní nahrávací zóna pro obrázky. Klik = výběr ze souborů, drop = přetažení z Finderu.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImageWell: View {
    let title: String
    @Binding var urls: [URL]
    var hint: String? = nil

    @State private var isTargeted = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.xs) {
                SectionLabel(title)
                Spacer()
                if !urls.isEmpty {
                    Text("\(urls.count)")
                        .font(.dsCaption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            if urls.isEmpty {
                emptyZone
            } else {
                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(urls, id: \.self) { thumbnail($0) }
                    addTile
                }
            }

            if let hint {
                Text(hint)
                    .font(.dsCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { handleDrop($0) }
    }

    private var emptyZone: some View {
        Button(action: openPanel) {
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.06) : DS.Palette.fieldBackground)
                .frame(height: 40)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .strokeBorder(isTargeted ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func thumbnail(_ url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(DS.Palette.fieldBackground)
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))

            Button {
                urls.removeAll { $0 == url }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(1)
        }
    }

    private var addTile: some View {
        Button(action: openPanel) {
            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                .fill(DS.Palette.fieldBackground)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
        }
        .buttonStyle(.plain)
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK { urls.append(contentsOf: panel.urls) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url,
                      let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                      type.conforms(to: .image) else { return }
                DispatchQueue.main.async {
                    if !urls.contains(url) { urls.append(url) }
                }
            }
        }
        return true
    }
}
