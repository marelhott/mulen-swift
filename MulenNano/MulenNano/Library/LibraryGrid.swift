//
//  LibraryGrid.swift
//  MulenNano
//
//  Znovupoužitelná mřížka obrázků s nativním kontextovým menu.
//

import SwiftUI

struct LibraryGrid: View {
    @Environment(AppEnvironment.self) private var env
    let images: [LibraryImage]
    var trashed: Bool = false
    var embedded: Bool = false
    /// Voláno při poklepu na dlaždici (otevře detail/editor).
    var onOpen: ((LibraryImage) -> Void)? = nil

    private let grid = [
        GridItem(.adaptive(minimum: 180, maximum: 280), spacing: DS.Space.m, alignment: .top)
    ]

    @ViewBuilder
    var body: some View {
        if embedded {
            gridContent
        } else {
            ScrollView {
                gridContent
                    .padding(DS.Space.l)
            }
        }
    }

    private var gridContent: some View {
        LazyVGrid(columns: grid, alignment: .leading, spacing: DS.Space.m) {
            ForEach(images) { tile($0) }
        }
    }

    private func tile(_ image: LibraryImage) -> some View {
        Group {
            if let nsImage = image.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                    .opacity(trashed ? 0.6 : 1)
            }
        }
        .contextMenu {
            if trashed {
                Button("Obnovit") { env.library.restore(image.id) }
            } else {
                if onOpen != nil {
                    Button("Detail…") { onOpen?(image) }
                    Divider()
                }
                Button("Stáhnout…") {
                    if let data = image.imageData {
                        ImageExport.save(data, suggestedName: "mulen-\(Int(image.createdAt.timeIntervalSince1970)).png")
                    }
                }
                Divider()
                Button("Smazat", role: .destructive) { env.library.moveToTrash(image.id) }
            }
        }
        .onTapGesture(count: 2) { onOpen?(image) }
        .onTapGesture(count: 1) { onOpen?(image) }
    }
}

// MARK: - Prázdný stav (sdílený)
struct LibraryEmptyState: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: DS.Space.m) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.quaternary)
            Text(title).font(.dsEmptyTitle).foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle).font(.dsCaption).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
