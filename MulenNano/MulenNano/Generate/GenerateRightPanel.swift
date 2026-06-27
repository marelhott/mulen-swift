//
//  GenerateRightPanel.swift
//  MulenNano
//
//  Pravý panel — výběr modelů, režimy promptu, grounding, provider.
//  Kompaktní, nativní, dle Apple Photos editačního panelu.
//

import SwiftUI

struct GenerateRightPanel: View {
    @Bindable var model: GenerateModel
    var enhancing: Bool = false
    var onEnhance: () -> Void = {}
    var onTemplates: () -> Void = {}
    var onCollections: () -> Void = {}

    private let presetColumns = [GridItem(.flexible(), spacing: DS.Space.s),
                                 GridItem(.flexible(), spacing: DS.Space.s)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                modelsSection
                Hairline()
                outputSection
                Hairline()
                promptModesSection
            }
            .padding(DS.Space.l)
        }
        .frame(minWidth: 220, idealWidth: 236, maxWidth: 280)
        .background(.clear)
    }

    // MARK: Výběr modelů
    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Model")
            LazyVGrid(columns: presetColumns, spacing: DS.Space.s) {
                ForEach(ModelPreset.all) { presetCard($0) }
            }
        }
    }

    private func presetCard(_ preset: ModelPreset) -> some View {
        let isActive = model.modelPresetID == preset.id
        return Button {
            model.selectPreset(preset)
        } label: {
            VStack(spacing: 1) {
                Text(preset.title)
                    .font(.system(size: 12, weight: .medium))
                Text(preset.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Space.s)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.14) : DS.Palette.fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .opacity(preset.enabled ? 1 : 0.4)
        .disabled(!preset.enabled)
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Výstup")

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Poměr stran")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $model.aspectRatio) {
                    ForEach(AspectRatioOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Rozlišení")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $model.resolution) {
                    ForEach(ResolutionOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }
        }
    }

    // MARK: Režimy promptu
    private var promptModesSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Režim")
            HStack(spacing: DS.Space.xs) {
                ForEach(SimpleLinkMode.allCases) { linkChip($0) }
            }
            HStack(spacing: DS.Space.xs) {
                Button(action: onEnhance) {
                    Group {
                        if enhancing { ProgressView().controlSize(.mini) }
                        else { Text("Vylepšit") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(model.prompt.isEmpty || enhancing)
                Button(action: onTemplates) { Text("Šablony").frame(maxWidth: .infinity) }
                Button(action: onCollections) { Text("Kolekce").frame(maxWidth: .infinity) }
            }
            .font(.dsCaption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func linkChip(_ m: SimpleLinkMode) -> some View {
        let isActive = model.simpleLinkMode == m
        return Button {
            model.simpleLinkMode = isActive ? nil : m
        } label: {
            Text(m.label)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.14) : DS.Palette.fieldBackground)
                )
                .foregroundStyle(isActive ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help(m.summary)
    }
}
