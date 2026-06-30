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

    private let presetColumns = [GridItem(.flexible(), spacing: DS.Space.s),
                                 GridItem(.flexible(), spacing: DS.Space.s)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                modelsSection
                Hairline()
                outputSection
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
                    .font(.dsStandardMedium)
                Text(preset.subtitle)
                    .font(.dsSmall)
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

                Text(model.aspectRatio.summary)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Rozlišení")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                CapsuleSegmentedPicker(
                    title: "Rozlišení",
                    options: ResolutionOption.allCases.map { ($0, $0.rawValue) },
                    selection: $model.resolution
                )

                Text(model.resolution.summary)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

}
