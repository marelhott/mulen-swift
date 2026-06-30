//
//  PhotoEditorPanel.swift
//  MulenNano
//
//  Pravý editační panel: segmentovka [Úpravy | Filtr | Oříznutí] + spodní akce
//  (Auto vylepšení / Vrátit / Použít). Vizuálně 1:1 s Apple Photos.
//

import SwiftUI

enum PhotoEditorTab: Hashable {
    case adjust, filter, crop
}

struct PhotoEditorPanel: View {
    @Bindable var session: PhotoEditingSession
    var onApply: () -> Void
    var onRevert: () -> Void

    @State private var tab: PhotoEditorTab = .adjust

    var body: some View {
        VStack(spacing: 0) {
            topToolbar
            Hairline()
            panelContent
            Spacer(minLength: 0)
            Hairline()
            bottomActions
        }
    }

    // MARK: Nástrojová lišta nahoře (segmentovka)

    private var topToolbar: some View {
        HStack(spacing: DS.Space.xs) {
            Button {
                autoEnhance()
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Automaticky vylepšit")
            .accessibilityLabel("Automaticky vylepšit")

            Spacer()

            Picker("", selection: $tab) {
                Text("Úpravy").tag(PhotoEditorTab.adjust)
                Text("Filtr").tag(PhotoEditorTab.filter)
                Text("Oříznutí").tag(PhotoEditorTab.crop)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
    }

    @ViewBuilder
    private var panelContent: some View {
        switch tab {
        case .adjust: AdjustPanel(session: session)
        case .filter: FilterPanel(session: session)
        case .crop:   CropPanel(session: session)
        }
    }

    // MARK: Spodní akce

    private var bottomActions: some View {
        HStack(spacing: DS.Space.s) {
            Button("Vrátit", role: .destructive, action: onRevert)
                .buttonStyle(.plain)
                .font(.dsStandardMedium)
                .foregroundStyle(.secondary)
                .disabled(session.isPristine)
            Spacer()
            Button("Použít", action: onApply)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(session.isPristine)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        .opacity(session.isPristine ? 0.6 : 1)
    }

    // MARK: Auto vylepšení

    /// Jednoduchá heuristika: lehký lift expozice/stínů + vibrance, ekvivalent „Auto" tlačítka Photos.
    private func autoEnhance() {
        if abs(session.state.exposure) < 0.01 { session.state.exposure = 0.12 }
        if abs(session.state.shadows)  < 0.01 { session.state.shadows  = 0.30 }
        if abs(session.state.highlights) < 0.01 { session.state.highlights = -0.20 }
        if abs(session.state.vibrance) < 0.01 { session.state.vibrance = 0.25 }
        if abs(session.state.definition) < 0.01 { session.state.definition = 0.18 }
        session.schedulePreviewRender()
    }
}
