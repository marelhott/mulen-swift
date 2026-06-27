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

    @State private var collectionTarget: LibraryImage?

    private let grid = [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: DS.Space.m)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: grid, spacing: DS.Space.m) {
                ForEach(images) { tile($0) }
            }
            .padding(DS.Space.l)
        }
        .sheet(item: $collectionTarget) { AssignCollectionSheet(image: $0) }
    }

    private func tile(_ image: LibraryImage) -> some View {
        Group {
            if let nsImage = image.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                    .clipped()
                    .opacity(trashed ? 0.6 : 1)
            }
        }
        .contextMenu {
            if trashed {
                Button("Obnovit") { env.library.restore(image.id) }
            } else {
                Button("Stáhnout…") {
                    if let data = image.imageData {
                        ImageExport.save(data, suggestedName: "mulen-\(Int(image.createdAt.timeIntervalSince1970)).png")
                    }
                }
                Button("Přidat do kolekce…") { collectionTarget = image }
                Divider()
                Button("Smazat", role: .destructive) { env.library.moveToTrash(image.id) }
            }
        }
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
