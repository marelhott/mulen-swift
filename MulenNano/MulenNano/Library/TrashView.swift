//
//  TrashView.swift
//  MulenNano
//
//  „Naposledy smazané" — koš s možností obnovit nebo vysypat.
//

import SwiftUI

struct TrashView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(spacing: 0) {
            if !env.library.trashed.isEmpty {
                HStack {
                    SectionLabel("Naposledy smazané")
                    Spacer()
                    Button("Vysypat koš", role: .destructive) { env.library.emptyTrash() }
                        .controlSize(.small)
                }
                .padding(.horizontal, DS.Space.xl)
                .padding(.vertical, DS.Space.m)
                Hairline()
            }

            if env.library.trashed.isEmpty {
                LibraryEmptyState(systemImage: "trash",
                                  title: "Koš je prázdný",
                                  subtitle: "Smazané obrázky se objeví tady.")
            } else {
                LibraryGrid(images: env.library.trashed, trashed: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
