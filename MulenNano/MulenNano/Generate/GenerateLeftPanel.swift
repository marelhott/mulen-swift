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

    // MARK: Počet — adjustment slider
    private var countSection: some View {
        PhotosSlider(
            systemImage: "square.grid.2x2",
            label: "Počet",
            value: Binding(get: { Double(model.count) }, set: { model.count = Int($0.rounded()) }),
            range: 1...5,
            step: 1
        )
    }

    // MARK: Prompt
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack {
                SectionLabel("Prompt")
                Spacer()
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

                Picker("", selection: $model.mode) {
                    ForEach(PromptMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: promptBinding)
                    .font(.dsLabel)
                    .scrollContentBackground(.hidden)
                    .frame(height: 64)
                    .padding(DS.Space.xs)
                if model.prompt.isEmpty {
                    Text("Prompt…")
                        .font(.dsLabel)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, DS.Space.s)
                        .padding(.vertical, DS.Space.s + 1)
                        .allowsHitTesting(false)
                }
            }
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

    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Picker("", selection: $model.variant) {
                ForEach(AdvancedVariant.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .help(model.variant.tooltip)

            Toggle("Zachovat identitu tváře", isOn: $model.faceIdentity)
                .font(.dsLabel)
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }

    // MARK: Vstupy
    private var inputsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            ImageWell(title: "Vstupní obrázky", urls: $model.sourceImages)

            if model.sourceImages.count > 1 {
                Picker("", selection: $model.multiRefMode) {
                    ForEach(MultiRefMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
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
}
