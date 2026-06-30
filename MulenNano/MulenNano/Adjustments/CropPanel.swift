//
//  CropPanel.swift
//  MulenNano
//
//  Záložka „Oříznutí" — poměry stran, překlopení, otočení, vyrovnání (kruhové kolečko).
//

import SwiftUI

struct CropPanel: View {
    @Bindable var session: PhotoEditingSession

    private let ratioColumns = [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: DS.Space.s)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                flipsRow
                Hairline()
                ratiosSection
                Hairline()
                straightenSection
            }
            .padding(DS.Space.s)
        }
    }

    // MARK: Překlopení / otočení

    private var flipsRow: some View {
        HStack(spacing: DS.Space.s) {
            SectionLabel("Zrcadlení").frame(maxWidth: .infinity, alignment: .leading)
            toggleButton(symbol: "arrow.left.and.right.right",
                         active: session.crop.flipHorizontal,
                         help: "Překlopit vodorovně") {
                session.crop.flipHorizontal.toggle()
                session.schedulePreviewRender()
            }
            toggleButton(symbol: "arrow.up.and.down.right",
                         active: session.crop.flipVertical,
                         help: "Překlopit svisle") {
                session.crop.flipVertical.toggle()
                session.schedulePreviewRender()
            }
            toggleButton(symbol: "rotate.left",
                         active: false,
                         help: "Otočit o 90° vlevo") {
                // 90° rotace = připravit na ořez; implementujeme přes straighten pikníkem později
            }
            .disabled(true)
        }
    }

    // MARK: Poměry

    private var ratiosSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Poměr stran")
            LazyVGrid(columns: ratioColumns, alignment: .leading, spacing: DS.Space.s) {
                ForEach(CropState.Aspect.allCases) { aspect in
                    let isSelected = session.crop.aspect == aspect
                    Button {
                        session.crop.aspect = aspect
                        session.schedulePreviewRender()
                    } label: {
                        Text(aspect.rawValue)
                            .font(.dsSmallMedium)
                            .foregroundStyle(isSelected ? Color.accentColor : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Space.xs)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : DS.Palette.fieldBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Vyrovnání (kruhové kolečko jako ve Photos)

    private var straightenSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack {
                SectionLabel("Vyrovnat")
                Spacer()
                Text("\(Int(session.crop.straighten.rounded()))°")
                    .font(.dsValue)
                    .foregroundStyle(.secondary)
            }
            StraightenDial(value: $session.crop.straighten) {
                session.schedulePreviewRender()
            }
            PhotosSlider(
                label: "Úhel",
                value: $session.crop.straighten,
                range: -45...45,
                step: 1,
                format: { "\(Int($0))°" },
                centered: true
            )
            .onChange(of: session.crop.straighten) { _, _ in
                session.schedulePreviewRender()
            }
        }
    }

    private func toggleButton(symbol: String, active: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Color.accentColor : .primary)
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(active ? Color.accentColor.opacity(0.12) : DS.Palette.fieldBackground)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Kruhový ovladač vyrovnání (tažením po kruhu → úhel -45…45°). Vizuál dle Photos.
struct StraightenDial: View {
    @Binding var value: Double
    var onChange: () -> Void

    private let size: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.Palette.fieldBorder, lineWidth: 1)
            Circle()
                .trim(from: 0.5, to: 0.5 + CGFloat(abs(value) / 90))
                .stroke(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(value < 0 ? 180 : 0))
                .frame(width: size, height: size)

            // Hlavní ryska
            Rectangle()
                .fill(Color.primary.opacity(0.7))
                .frame(width: 2, height: size / 2 - 6)
                .offset(y: -size / 4)
                .rotationEffect(.degrees(value))

            // Středový puntík
            Circle()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 6, height: 6)

            // Hranice ±45°
            ForEach([-45.0, 45.0], id: \.self) { angle in
                Rectangle()
                    .fill(Color.primary.opacity(0.18))
                    .frame(width: 1, height: 6)
                    .offset(y: -size / 2 + 2)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let dx = g.location.x - size / 2
                    let dy = g.location.y - size / 2
                    var angle = atan2(dx, -dy) * 180 / .pi
                    angle = max(-45, min(45, angle))
                    value = angle
                    onChange()
                }
        )
        .frame(maxWidth: .infinity)
    }
}
