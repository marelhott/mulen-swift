//
//  GenerateLeftPanel.swift
//  MulenNano
//
//  Levý ovládací panel — kompaktní, nativní proporce dle Apple Photos.
//

import SwiftUI

struct GenerateLeftPanel: View {
    @Bindable var model: GenerateModel
    var promptText: Binding<String>? = nil
    var busy: Bool = false
    var savedPrompts: [SavedPrompt] = []
    var canUndoPrompt: Bool = false
    var canRedoPrompt: Bool = false
    var onGenerate: () -> Void = {}
    var onVariace: () -> Void = {}
    var onInterpretace: () -> Void = {}
    var onTemplates: () -> Void = {}
    var onSavePrompt: () -> Void = {}
    var onManagePrompts: () -> Void = {}
    var onPickSaved: (String) -> Void = { _ in }
    var onUndoPrompt: () -> Void = {}
    var onRedoPrompt: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                actions
                Hairline()
                countSection
                Hairline()
                promptSection
                Hairline()
                inputsSection
            }
            .padding(DS.Space.l)
        }
        .frame(minWidth: 240, idealWidth: 256, maxWidth: 300)
        .background(.clear)
    }

    // MARK: Akce
    private var actions: some View {
        VStack(spacing: DS.Space.s) {
            Button(action: onGenerate) {
                Text("Generovat").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canGenerate || busy)

            HStack(spacing: DS.Space.s) {
                Button(action: onVariace) { Text("Variace").frame(maxWidth: .infinity) }
                    .help("Variace seedu — 3 obrázky ze stejného promptu")
                Button(action: onInterpretace) { Text("Interpretace").frame(maxWidth: .infinity) }
                    .help("AI vytvoří 3 různé verze promptu a obrázek pro každou")
            }
            .font(.dsCaption)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!model.canGenerate || busy)
        }
    }

    // MARK: Počet
    private var countSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Počet")

            Picker("Počet obrázků", selection: $model.count) {
                ForEach(1...5, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            } currentValueLabel: {
                Text("\(model.count)")
                    .font(.dsStandard)
                    .foregroundStyle(.primary)
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help("Kolik obrázků se má v této jedné generaci vytvořit.")

            Text(countSummary)
                .font(.dsCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Prompt
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.xs) {
                SectionLabel("Prompt")
                Spacer(minLength: 0)
                Button(action: onTemplates) {
                    Image(systemName: "rectangle.stack")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Šablony promptů")
                savedMenu
                Button(action: onUndoPrompt) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.plain)
                .foregroundStyle(canUndoPrompt ? .secondary : .tertiary)
                .disabled(!canUndoPrompt)
                .help("Zpět")
                Button(action: onRedoPrompt) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .buttonStyle(.plain)
                .foregroundStyle(canRedoPrompt ? .secondary : .tertiary)
                .disabled(!canRedoPrompt)
                .help("Znovu")
            }

            Picker("", selection: $model.mode) {
                ForEach(PromptMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            TextEditor(text: promptBinding)
                .font(.dsLabel)
                .scrollContentBackground(.hidden)
                .frame(height: 64)
                .padding(DS.Space.xs)
            .background(RoundedRectangle(cornerRadius: DS.Radius.m).fill(DS.Palette.fieldBackground))

            if model.mode == .interpretace {
                advancedControls
            }
        }
    }

    private var savedMenu: some View {
        Menu {
            Button("Uložit prompt…", action: onSavePrompt)
                .disabled(model.prompt.isEmpty)
            Button("Spravovat prompty…", action: onManagePrompts)
            if !savedPrompts.isEmpty {
                Divider()
                ForEach(savedPrompts) { sp in
                    Button(sp.name) { onPickSaved(sp.prompt) }
                }
            }
        } label: {
            Image(systemName: "bookmark")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .controlSize(.small)
    }

    private var promptBinding: Binding<String> {
        promptText ?? $model.prompt
    }

    private var countSummary: String {
        model.count == 1
            ? "Vygeneruje 1 obrázek."
            : "Vygeneruje \(model.count) obrázky v jednom běhu."
    }

    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Picker("", selection: $model.variant) {
                ForEach(AdvancedVariant.allCases) { variant in
                    Text(variant.subtitle).tag(variant)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .help(model.variant.tooltip)

            Text(model.variant.tooltip)
                .font(.dsCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Zachovat identitu tváře", isOn: $model.faceIdentity)
                .font(.dsLabel)
                .toggleStyle(.switch)
                .controlSize(.mini)

            Text("Když je zapnuto, aplikace se víc drží podoby obličeje ze vstupní reference.")
                .font(.dsCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Vstupy
    private var inputsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            ImageWell(title: "Vstupní obrázky", urls: $model.sourceImages)

            if !model.sourceImages.isEmpty {
                referenceModeSection
            }

            if model.sourceImages.count > 1 {
                Picker("", selection: $model.multiRefMode) {
                    ForEach(MultiRefMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)

                Text(model.multiRefMode.summary)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ImageWell(title: "Stylové obrázky", urls: $model.styleImages)

            if !model.styleImages.isEmpty {
                PhotosSlider(
                    systemImage: "paintbrush",
                    label: "Síla stylu",
                    value: $model.styleStrength,
                    range: 0...100,
                    format: { "\(Int($0)) %" }
                )
            }

            ImageWell(title: "Proprietární prvky", urls: $model.assetImages,
                      hint: "Logo / produkt — jen obsahové doplnění výstupu.")
        }
    }

    private var referenceModeSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("Jak použít reference")
                .font(.dsCaption)
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Space.xs) {
                ForEach(SimpleLinkMode.allCases) { mode in
                    referenceModeChip(mode)
                }
            }

            if let mode = model.simpleLinkMode {
                Text(mode.summary)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: model.simpleLinkMode)
    }

    private func referenceModeChip(_ mode: SimpleLinkMode) -> some View {
        let isActive = model.simpleLinkMode == mode
        return Button {
            model.simpleLinkMode = isActive ? nil : mode
        } label: {
            Text(mode.label)
                .font(.dsStandardMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.14) : DS.Palette.fieldBackground)
                )
                .foregroundStyle(isActive ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help(mode.summary)
    }
}
