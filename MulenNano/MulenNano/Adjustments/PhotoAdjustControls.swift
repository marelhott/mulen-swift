//
//  PhotoAdjustControls.swift
//  MulenNano
//
//  Vizuální komponenty editačního panelu přesně v jazyce Apple Photos:
//  – rozbalitelná skupina (chevron + souhrnný posuvník + hodnota)
//  – listový posuvník (ten samý PhotosSlider, s formátovačem a tlačítkem reset)
//

import SwiftUI

/// Formát procentuální hodnoty posuvníku Photos (± %).
enum PhotosValue {
    /// 0 → "0", 0.3 → "30", -0.4 → "−40" (přepíná znaménko vzhledem k 0).
    static func signed(_ v: Double, scale: Double = 100) -> String {
        let pct = (v * scale).rounded() / 1
        if abs(pct) < 0.5 { return "0" }
        return pct > 0 ? "+\(Int(pct))" : "−\(Int(-pct))"
    }
    /// Pro 0…1 posuvníky: 0 → "0", 1 → "100".
    static func plain(_ v: Double, scale: Double = 100) -> String {
        String(Int((v * scale).rounded()))
    }
}

// MARK: - Rozbalitelná skupina (Světlo / Barva / Černobílá)

struct PhotosAdjustGroup<Content: View>: View {
    let title: String
    let symbol: String
    let summary: Double          // souhrnná hodnota (-1...1)
    var summaryFormat: (Double) -> String = { PhotosValue.signed($0) }
    @Binding var isExpanded: Bool
    var hasAuto: Bool = false
    var onAuto: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: DS.Space.xxs) {
            // Hlavička: chevron + název + souhrnný posuvník + hodnota (+Auto)
            HStack(spacing: DS.Space.s) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 10)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(title)
                            .font(.dsStandardMedium)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) — \(isExpanded ? "Sbalit" : "Rozbalit")")

                Spacer(minLength: DS.Space.xs)

                if hasAuto, let onAuto {
                    Button(action: onAuto) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Automaticky (\(title))")
                    .accessibilityLabel("Auto \(title)")
                }

                Text(summaryFormat(summary))
                    .font(.dsValue)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
                    .opacity(abs(summary) > 0.005 ? 1 : 0.5)
            }
            .padding(.horizontal, DS.Space.s)
            .frame(height: 30)

            if isExpanded {
                VStack(spacing: DS.Space.xxs) {
                    content()
                }
                .padding(.leading, DS.Space.m)
                .padding(.trailing, DS.Space.xxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Listový řádek s tlačítkem reset (u hodnoty ≠ 0)

struct PhotosLeafSlider: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = -1...1
    var centered: Bool = true
    var format: (Double) -> String = { PhotosValue.signed($0) }
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            PhotosSlider(
                label: label,
                value: $value,
                range: range,
                format: format,
                centered: centered
            )
            .onChange(of: value) { _, _ in onChange() }

            if abs(value) > 0.005 {
                Button {
                    value = centered ? 0 : range.lowerBound
                    onChange()
                } label: {
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .help("Reset \(label)")
                .accessibilityLabel("Reset \(label)")
            }
        }
        .animation(.easeInOut(duration: 0.12), value: abs(value) > 0.005)
    }
}
