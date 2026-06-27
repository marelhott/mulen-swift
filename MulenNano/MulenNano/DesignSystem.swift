//
//  DesignSystem.swift
//  MulenNano
//
//  Designové tokeny — jeden zdroj pravdy. Proporce a velikosti dle Apple Photos (macOS, světlý režim).
//  Pravidla: nativní San Francisco, malé klidné fonty, žádné bublinové podklady, žádné stíny.
//

import SwiftUI

enum DS {
    // MARK: Mezery (4pt mřížka)
    enum Space {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let s:   CGFloat = 8
        static let m:   CGFloat = 12
        static let l:   CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 28
    }

    // MARK: Poloměry (jemné, dle macOS)
    enum Radius {
        static let s:  CGFloat = 5
        static let m:  CGFloat = 7
        static let l:  CGFloat = 10
    }

    enum Palette {
        static let hairline = Color.primary.opacity(0.08)
        static let fieldBackground = Color.primary.opacity(0.04)
    }
}

// MARK: - Typografie (nativní velikosti macOS)
extension Font {
    /// Drobný šedý nadpis skupiny (jako „ÚPRAVA" v editoru Fotek).
    static let dsSection = Font.system(size: 11, weight: .semibold)
    /// Běžný popisek ovládacího prvku (~13pt nativní).
    static let dsLabel   = Font.system(size: 13, weight: .regular)
    /// Sekundární drobný text.
    static let dsCaption = Font.system(size: 11, weight: .regular)
    static let dsValue   = Font.system(size: 11, weight: .regular).monospacedDigit()
    /// Nadpis prázdného stavu — klidný, ne velký.
    static let dsEmptyTitle = Font.system(size: 15, weight: .medium)
}

// MARK: - Drobný šedý nadpis skupiny (Apple Photos styl)
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.dsSection)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Jemný oddělovač
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(DS.Palette.hairline)
            .frame(height: 1)
    }
}
