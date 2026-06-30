//
//  PhotosSlider.swift
//  MulenNano
//
//  Posuvník ve stylu Apple Photos editačního panelu:
//  zaoblený řádek = ikona + popisek + táhnutelná dráha + svislá ryska polohy + hodnota vpravo.
//

import SwiftUI

struct PhotosSlider: View {
    var systemImage: String? = nil
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double? = nil
    var format: (Double) -> String = { String(Int($0.rounded())) }
    /// Centrovaný posuvník (0 uprostřed dráhy). Používá se pro Warmth/Tint/Vignette/Neutrals/Tone.
    var centered: Bool = false

    private let height: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value - range.lowerBound) / span : 0
            let x = max(0, min(w, w * fraction))
            let centerX = centered ? (w * ((0 - range.lowerBound) / span)).clampedToRange(0...w) : 0

            ZStack(alignment: .leading) {
                if centered {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.16))
                        .frame(width: abs(x - centerX))
                        .offset(x: min(x, centerX))
                } else {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.16))
                        .frame(width: x)
                }

                if centered {
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1)
                        .offset(x: centerX - 0.5)
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.28))
                    .frame(width: 1.5)
                    .offset(x: x - 0.75)

                HStack(spacing: DS.Space.s) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                    }
                    Text(label)
                        .font(.dsSection)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: DS.Space.s)
                    Text(format(value))
                        .font(.dsValue)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Space.m)
            }
            .frame(width: w, height: height)
            .background(DS.Palette.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let f = max(0, min(1, g.location.x / w))
                        var v = range.lowerBound + f * span
                        if let step { v = (v / step).rounded() * step }
                        value = min(range.upperBound, max(range.lowerBound, v))
                    }
            )
        }
        .frame(height: height)
    }
}

private extension Comparable {
    func clampedToRange(_ limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

struct CompactScaleControl: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var sliderWidth: CGFloat = 96
    let help: String

    var body: some View {
        HStack(spacing: 7) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 16, height: 20)
            }
            .disabled(value <= range.lowerBound)

            Slider(value: $value, in: range)
                .controlSize(.mini)
                .frame(width: sliderWidth)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 16, height: 20)
            }
            .disabled(value >= range.upperBound)
        }
        .font(.dsSmallMedium)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .help(help)
    }
}
