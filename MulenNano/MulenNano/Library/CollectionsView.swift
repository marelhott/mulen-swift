//
//  CollectionsView.swift
//  MulenNano
//
//  „Kolekce" — seznam kolekcí vlevo, obrázky vybrané kolekce vpravo.
//

import SwiftUI

struct CollectionsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selected: UUID?

    var body: some View {
        Group {
            if env.library.collections.isEmpty {
                LibraryEmptyState(systemImage: "rectangle.stack",
                                  title: "Žádné kolekce",
                                  subtitle: "Kolekce vytvoříš u obrázku přes Přidat do kolekce.")
            } else {
                HSplitView {
                    collectionList
                        .frame(minWidth: 180, idealWidth: 200, maxWidth: 260)
                    collectionContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { if selected == nil { selected = env.library.collections.first?.id } }
    }

    private var collectionList: some View {
        List(selection: $selected) {
            ForEach(env.library.collections) { c in
                Label("\(c.name)  (\(env.library.images(in: c.id).count))", systemImage: "rectangle.stack")
                    .tag(c.id)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var collectionContent: some View {
        if let id = selected {
            let imgs = env.library.images(in: id)
            if imgs.isEmpty {
                LibraryEmptyState(systemImage: "photo", title: "Kolekce je prázdná")
            } else {
                LibraryGrid(images: imgs)
            }
        } else {
            LibraryEmptyState(systemImage: "rectangle.stack", title: "Vyber kolekci")
        }
    }
}
