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
        static let m:  CGFloat = 9
        static let l:  CGFloat = 13
    }

    enum Palette {
        static let hairline = Color.primary.opacity(0.11)
        static let fieldBackground = Color.primary.opacity(0.055)
        static let fieldBorder = Color.primary.opacity(0.12)
    }
}

// MARK: - Typography
extension Font {
    // The app intentionally uses only these two text sizes.
    static let dsStandard = Font.system(size: 12, weight: .regular)
    static let dsStandardMedium = Font.system(size: 12, weight: .medium)
    static let dsStandardSemibold = Font.system(size: 12, weight: .semibold)
    static let dsSmall = Font.system(size: 11, weight: .regular)
    static let dsSmallMedium = Font.system(size: 11, weight: .medium)
    static let dsSmallSemibold = Font.system(size: 11, weight: .semibold)

    static let dsSection = Font.dsSmallSemibold
    static let dsLabel = Font.dsStandard
    static let dsCaption = Font.dsSmall
    static let dsValue = Font.dsSmall.monospacedDigit()
    static let dsEmptyTitle = Font.dsStandardMedium
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
