//
//  LibraryView.swift
//  MulenNano
//
//  Hlavní knihovna „Vše" — mřížka všech vygenerovaných obrázků.
//

import SwiftUI

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.library.images.isEmpty {
                LibraryEmptyState(systemImage: "photo.on.rectangle.angled",
                                  title: "Knihovna je prázdná",
                                  subtitle: "Vygenerované obrázky se objeví tady.")
            } else {
                LibraryGrid(images: env.library.images)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
    }
}
