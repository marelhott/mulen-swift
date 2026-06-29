//
//  ToolViews.swift
//  MulenNano
//
//  Obrazovky nástrojů: Reframe, Batch, Face Swap, AI Upscaler.
//

import SwiftUI

// MARK: - Reframe
struct ReframeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var images: [URL] = []
    @State private var selected: Set<String> = ["closeup", "long-shot", "low-angle", "high-angle"]
    @State private var busy = false
    @State private var error: String?

    private let chips = [GridItem(.adaptive(minimum: 92), spacing: DS.Space.xs)]

    var body: some View {
        ToolScaffold(runLabel: "Reframe (\(selected.count))",
                     canRun: !images.isEmpty && !selected.isEmpty, busy: busy, error: error) {
            ImageWell(title: "Vstupní obrázek", urls: $images)
            SectionLabel("Perspektivy")
            LazyVGrid(columns: chips, alignment: .leading, spacing: DS.Space.xs) {
                ForEach(ReframePerspective.all) { p in
                    Chip(label: p.label, active: selected.contains(p.id)) {
                        if selected.contains(p.id) { selected.remove(p.id) } else { selected.insert(p.id) }
                    }
                }
            }
        } onRun: { run() }
    }

    private func run() {
        guard let url = images.first else { return }
        let engine = ToolEngine(env: env)
        guard let input = engine.loadInput(url) else { return }
        let picked = ReframePerspective.all.filter { selected.contains($0.id) }
        busy = true; error = nil
        Task {
            defer { busy = false }
            for p in picked {
                do { try await engine.edit(inputs: [input], prompt: p.prompt, label: "Reframe", variant: p.label) }
                catch let e { error = (e as? LocalizedError)?.errorDescription ?? "\(e)" }
            }
        }
    }
}

// MARK: - Batch
struct BatchView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var images: [URL] = []
    @State private var preset: BatchPreset = BatchPreset.all[0]
    @State private var custom = ""
    @State private var variants: Double = 1
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ToolScaffold(runLabel: "Spustit dávku",
                     canRun: !images.isEmpty && !busy, busy: busy, error: error) {
            ImageWell(title: "Vstupní obrázky", urls: $images)
            SectionLabel("Preset")
            Picker("", selection: $preset) {
                ForEach(BatchPreset.all) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().controlSize(.small)

            SectionLabel("Doplňující instrukce")
            TextField("volitelné…", text: $custom, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            PhotosSlider(systemImage: "rectangle.on.rectangle", label: "Varianty",
                         value: $variants, range: 1...3, step: 1)
        } onRun: { run() }
    }

    private func run() {
        let engine = ToolEngine(env: env)
        let inputs = images.compactMap { engine.loadInput($0) }
        let total = Int(variants)
        busy = true; error = nil
        Task {
            defer { busy = false }
            for input in inputs {
                for i in 0..<total {
                    let base = BatchPreset.buildPrompt(preset, custom: custom)
                    let prompt = total <= 1 ? base : "\(base)\n\nVytvoř variantu \(i + 1) z \(total). Zachovej hlavní zadání, ale nabídni jemně odlišné řešení v detailu, světle nebo kompozici."
                    do { try await engine.edit(inputs: [input], prompt: prompt, label: preset.title) }
                    catch let e { error = (e as? LocalizedError)?.errorDescription ?? "\(e)" }
                }
            }
        }
    }
}

// MARK: - Face Swap
struct FaceSwapView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var targetImages: [URL] = []
    @State private var sourceImages: [URL] = []
    @State private var mode: FaceSwapMode = .face
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ToolScaffold(runLabel: "Prohodit",
                     canRun: !targetImages.isEmpty && !sourceImages.isEmpty && !busy, busy: busy, error: error) {
            ImageWell(title: "Cílový obrázek (scéna)", urls: $targetImages)
            ImageWell(title: "Zdroj identity (obličej)", urls: $sourceImages)
            SectionLabel("Rozsah")
            Picker("", selection: $mode) {
                ForEach(FaceSwapMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().controlSize(.small)
        } onRun: { run() }
    }

    private func run() {
        guard let targetURL = targetImages.first, let sourceURL = sourceImages.first,
              let targetData = try? Data(contentsOf: targetURL),
              let sourceData = try? Data(contentsOf: sourceURL),
              let composite = ToolImage.composite(targetData: targetData, sourceData: sourceData) else {
            error = "Nepodařilo se připravit obrázky."
            return
        }
        let engine = ToolEngine(env: env)
        busy = true; error = nil
        Task {
            defer { busy = false }
            do { try await engine.edit(inputs: [composite], prompt: FaceSwapPrompt.build(mode: mode), label: "Face swap") }
            catch let e { error = (e as? LocalizedError)?.errorDescription ?? "\(e)" }
        }
    }
}

// MARK: - AI Upscaler
struct UpscalerView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var images: [URL] = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ToolScaffold(runLabel: "Zvětšit a doostřit",
                     canRun: !images.isEmpty && !busy, busy: busy, error: error) {
            ImageWell(title: "Vstupní obrázky", urls: $images)
            Text("Zvýší rozlišení a detail při zachování obsahu (přes Gemini).")
                .font(.dsCaption).foregroundStyle(.secondary)
        } onRun: { run() }
    }

    private func run() {
        let engine = ToolEngine(env: env)
        let inputs = images.compactMap { engine.loadInput($0) }
        busy = true; error = nil
        Task {
            defer { busy = false }
            for input in inputs {
                do { try await engine.edit(inputs: [input], prompt: UpscalePrompt.prompt, label: "Upscale") }
                catch let e { error = (e as? LocalizedError)?.errorDescription ?? "\(e)" }
            }
        }
    }
}

// MARK: - Chip
private struct Chip: View {
    let label: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.dsStandardMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(active ? Color.accentColor.opacity(0.16) : DS.Palette.fieldBackground)
                )
                .foregroundStyle(active ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}
