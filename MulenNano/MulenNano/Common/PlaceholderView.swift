//
//  PlaceholderView.swift
//  MulenNano
//
//  Dočasný obsah pro sekce, které teprve postavíme (podle pořadí v PLAN.md).
//

import SwiftUI

struct PlaceholderView: View {
    let item: SidebarItem

    var body: some View {
        ContentUnavailableView {
            Label(item.title, systemImage: item.systemImage)
        } description: {
            Text("Tato sekce se připravuje.")
        }
        .navigationTitle(item.title)
    }
}

#Preview {
    PlaceholderView(item: .generate)
        .frame(width: 800, height: 600)
}
