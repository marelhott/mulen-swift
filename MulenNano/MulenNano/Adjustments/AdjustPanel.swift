//
//  AdjustPanel.swift
//  MulenNano
//
//  Záložka „Úpravy" — rozbalitelné skupiny posuvníků přesně jako Apple Photos:
//  Světlo / Barva / Černobílá  +  samostatné Definition / Sharpness / Noise /
//  Vignette / Sepia / Grain.
//

import SwiftUI

struct AdjustPanel: View {
    @Bindable var session: PhotoEditingSession

    @State private var expandedGroup: AdjustGroup? = .light

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                ForEach(AdjustGroup.allCases, id: \.self) { group in
                    if group == .bw {
                        bwGroup
                    } else {
                        PhotosAdjustGroup(
                            title: group.title,
                            symbol: group.symbol,
                            summary: session.summary(for: group),
                            isExpanded: Binding(
                                get: { expandedGroup == group },
                                set: { expandedGroup = $0 ? group : nil }
                            ),
                            hasAuto: group == .light,
                            onAuto: group == .light ? { autoLight() } : nil
                        ) {
                            leafs(for: group)
                        }
                    }
                }

                Hairline().padding(.vertical, DS.Space.xxs)

                // Samostatné řádkové úpravy (jako v Photos za Světlem/Barvou)
                PhotosLeafSlider(label: "Definice",
                                 value: $session.state.definition,
                                 format: { PhotosValue.signed($0) },
                                 onChange: renderPreview)
                PhotosLeafSlider(label: "Ostrost",
                                 value: $session.state.sharpness,
                                 range: 0...1, centered: false,
                                 format: { PhotosValue.plain($0) },
                                 onChange: renderPreview)
                PhotosLeafSlider(label: "Redukce šumu",
                                 value: $session.state.noiseReduction,
                                 range: 0...1, centered: false,
                                 format: { PhotosValue.plain($0) },
                                 onChange: renderPreview)
                PhotosLeafSlider(label: "Vinetace",
                                 value: $session.state.vignette,
                                 format: { PhotosValue.signed($0) },
                                 onChange: renderPreview)
                PhotosLeafSlider(label: "Sépie",
                                 value: $session.state.sepia,
                                 range: 0...1, centered: false,
                                 format: { PhotosValue.plain($0) },
                                 onChange: renderPreview)
                PhotosLeafSlider(label: "Zrno",
                                 value: $session.state.grain,
                                 range: 0...1, centered: false,
                                 format: { PhotosValue.plain($0) },
                                 onChange: renderPreview)

                Spacer(minLength: DS.Space.s)
            }
            .padding(.horizontal, DS.Space.s)
            .padding(.top, DS.Space.s)
        }
    }

    /// Auto jen pro Světlo (jemný lift expozice/stínů/kontrastu).
    private func autoLight() {
        if abs(session.state.exposure)  < 0.01 { session.state.exposure  = 0.10 }
        if abs(session.state.shadows)   < 0.01 { session.state.shadows   = 0.28 }
        if abs(session.state.highlights) < 0.01 { session.state.highlights = -0.18 }
        if abs(session.state.contrast)  < 0.01 { session.state.contrast  = 0.08 }
        session.schedulePreviewRender()
    }

    // MARK: Leaf sliders per group

    @ViewBuilder
    private func leafs(for group: AdjustGroup) -> some View {
        switch group {
        case .light:
            PhotosLeafSlider(label: "Expozice",      value: $session.state.exposure, onChange: renderPreview)
            PhotosLeafSlider(label: "Lesk",          value: $session.state.brilliance, onChange: renderPreview)
            PhotosLeafSlider(label: "Světla",        value: $session.state.highlights, onChange: renderPreview)
            PhotosLeafSlider(label: "Stíny",         value: $session.state.shadows, onChange: renderPreview)
            PhotosLeafSlider(label: "Jas",           value: $session.state.brightness, onChange: renderPreview)
            PhotosLeafSlider(label: "Kontrast",      value: $session.state.contrast, onChange: renderPreview)
            PhotosLeafSlider(label: "Černý bod",     value: $session.state.blackPoint, onChange: renderPreview)
        case .color:
            PhotosLeafSlider(label: "Saturace",      value: $session.state.saturation, onChange: renderPreview)
            PhotosLeafSlider(label: "Vibrance",      value: $session.state.vibrance, onChange: renderPreview)
            PhotosLeafSlider(label: "Teplo",         value: $session.state.warmth, onChange: renderPreview)
            PhotosLeafSlider(label: "Odstín",        value: $session.state.tint, onChange: renderPreview)
        case .bw:
            EmptyView()
        }
    }

    // MARK: Skupina Černobílá (chování: přepínač zapnutí)

    private var bwGroup: some View {
        VStack(spacing: DS.Space.xxs) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
                    .rotationEffect(.degrees(session.state.blackAndWhite ? 90 : 0))
                Image(systemName: AdjustGroup.bw.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(AdjustGroup.bw.title)
                    .font(.dsStandardMedium)
                Spacer(minLength: DS.Space.xs)
                Toggle("", isOn: $session.state.blackAndWhite)
                    .labelsHidden()
                    .controlSize(.small)
                    .onChange(of: session.state.blackAndWhite) { _, _ in
                        session.schedulePreviewRender()
                    }
            }
            .padding(.horizontal, DS.Space.s)
            .frame(height: 30)

            if session.state.blackAndWhite {
                VStack(spacing: DS.Space.xxs) {
                    PhotosLeafSlider(label: "Intenzita", value: $session.state.bwIntensity,
                                     range: 0...1, centered: false,
                                     format: { PhotosValue.plain($0) },
                                     onChange: renderPreview)
                    PhotosLeafSlider(label: "Neutrály",  value: $session.state.bwNeutrals, onChange: renderPreview)
                    PhotosLeafSlider(label: "Tón",       value: $session.state.bwTone, onChange: renderPreview)
                }
                .padding(.leading, DS.Space.m)
                .padding(.trailing, DS.Space.xxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func renderPreview() {
        session.schedulePreviewRender()
    }
}
