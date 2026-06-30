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

// MARK: - iOS-style segmented control used in the generation panels
private enum CapsuleSegmentedPickerMetrics {
    static let controlHeight: CGFloat = 28
    static let outerPadding: CGFloat = 3
    static let trackHeight: CGFloat = 24
    static let selectedHeight: CGFloat = 22
    static let cornerRadius: CGFloat = 14
    static let fontSize: CGFloat = 11
    static let horizontalSegmentPadding: CGFloat = 0
}

struct CapsuleSegmentedPicker<Value: Hashable>: View {
    let title: String
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    @Namespace private var selectionTransition

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option.value
                    }
                } label: {
                    Text(option.label)
                        .font(.system(size: CapsuleSegmentedPickerMetrics.fontSize, weight: .medium))
                        .foregroundStyle(Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255))
                        .padding(.horizontal, CapsuleSegmentedPickerMetrics.horizontalSegmentPadding)
                        .frame(maxWidth: .infinity)
                        .frame(height: CapsuleSegmentedPickerMetrics.trackHeight)
                        .background {
                            if selection == option.value {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                    }
                                    .shadow(color: Color.black.opacity(0.08), radius: 1.5, x: 0, y: 1)
                                    .frame(height: CapsuleSegmentedPickerMetrics.selectedHeight)
                                    .matchedGeometryEffect(id: "selection", in: selectionTransition)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
        .frame(height: CapsuleSegmentedPickerMetrics.trackHeight)
        .background(Color(red: 0.93, green: 0.93, blue: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: CapsuleSegmentedPickerMetrics.trackHeight / 2, style: .continuous))
        .padding(.horizontal, CapsuleSegmentedPickerMetrics.outerPadding)
        .frame(height: CapsuleSegmentedPickerMetrics.controlHeight)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: CapsuleSegmentedPickerMetrics.cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
