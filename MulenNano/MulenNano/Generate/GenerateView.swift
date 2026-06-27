//
//  GenerateView.swift
//  MulenNano
//
//  Generovací pohled — 3 sloupce. Koordinuje veškerou generovací logiku (1:1 s webem):
//  generování, Variace (seed×3), Interpretace (AI×3), Vylepšit, šablony, kolekce, akce u výsledků.
//

import SwiftUI
import UniformTypeIdentifiers

struct GenerateView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = GenerateModel()

    @State private var isGenerating = false
    @State private var isEnhancing = false
    @State private var errorMessage: String?
    @State private var statusText: String?

    @State private var showTemplates = false
    @State private var showCollections = false
    @State private var showSavePrompt = false
    @State private var showManagePrompts = false
    @State private var collectionTarget: LibraryImage?
    @State private var detailImage: LibraryImage?
    @State private var detailEditImageID: UUID?
    @State private var promptHistory: [String] = [""]
    @State private var promptFuture: [String] = []
    @State private var suppressPromptHistory = false

    private let grid = [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: DS.Space.m)]

    private enum GenMode { case normal, variace, interpretace }

    var body: some View {
        HSplitView {
            GenerateLeftPanel(
                model: model,
                promptText: promptBinding,
                busy: isGenerating,
                savedPrompts: env.savedPrompts.prompts,
                canUndoPrompt: canUndoPrompt,
                canRedoPrompt: canRedoPrompt,
                onGenerate: { run(.normal) },
                onVariace: { run(.variace) },
                onInterpretace: { run(.interpretace) },
                onSavePrompt: { showSavePrompt = true },
                onManagePrompts: { showManagePrompts = true },
                onPickSaved: { setPrompt($0) },
                onUndoPrompt: undoPrompt,
                onRedoPrompt: redoPrompt
            )
            results
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            GenerateRightPanel(
                model: model,
                enhancing: isEnhancing,
                onEnhance: enhance,
                onTemplates: { showTemplates = true },
                onCollections: { showCollections = true }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showTemplates) {
            TemplatesSheet { model.prompt = $0 }
        }
        .sheet(isPresented: $showCollections) {
            CollectionsSheet()
        }
        .sheet(isPresented: $showSavePrompt) {
            SavePromptSheet(prompt: model.prompt)
        }
        .sheet(isPresented: $showManagePrompts) {
            ManagePromptsSheet { setPrompt($0) }
                .environment(env)
        }
        .sheet(item: $collectionTarget) { image in
            AssignCollectionSheet(image: image)
        }
        .sheet(item: $detailImage) { image in
            GeneratedImageDetailSheet(
                image: image,
                busy: detailEditImageID == image.id && isGenerating,
                errorMessage: errorMessage,
                onRegenerate: { iterate(from: image, prompt: $0) },
                onDownload: { download(image) },
                onDelete: {
                    env.library.moveToTrash(image.id)
                    detailImage = nil
                },
                onAssignCollection: { collectionTarget = image },
                onUndo: { env.library.undoLastRevision(image.id) },
                onRedo: { env.library.redoLastRevision(image.id) }
            )
            .environment(env)
        }
        .onAppear {
            if promptHistory == [""] {
                promptHistory = [model.prompt]
            }
        }
        .onChange(of: model.prompt) { _, newValue in
            guard !suppressPromptHistory else { return }
            guard promptHistory.last != newValue else { return }
            promptHistory.append(newValue)
            if promptHistory.count > 100 {
                promptHistory.removeFirst(promptHistory.count - 100)
            }
            promptFuture.removeAll()
        }
    }

    // MARK: Střed — výsledky
    private var results: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel("Výsledky generování")
                Spacer()
                if isGenerating {
                    if let statusText {
                        Text(statusText).font(.dsCaption).foregroundStyle(.secondary)
                    }
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, DS.Space.xl)
            .padding(.vertical, DS.Space.m)

            Hairline()

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.dsCaption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, DS.Space.xl).padding(.vertical, DS.Space.s)
            }

            if env.library.images.isEmpty && !isGenerating {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: grid, spacing: DS.Space.m) {
                        if isGenerating { placeholderTile }
                        ForEach(env.library.images) { resultTile($0) }
                    }
                    .padding(DS.Space.xl)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.m) {
            Spacer()
            Image(systemName: "photo")
                .font(.system(size: 34, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("Zatím žádné výsledky")
                .font(.dsEmptyTitle)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderTile: some View {
        RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
            .fill(.quaternary)
            .aspectRatio(1, contentMode: .fit)
            .overlay { ProgressView() }
    }

    private func resultTile(_ image: LibraryImage) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if let nsImage = image.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if let label = image.variantLabel {
                            Text(label)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(6)
                        }
                    }
            }
            if !image.prompt.isEmpty {
                Text(image.prompt)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { detailImage = image }
        .contextMenu {
            Button("Detail…") { detailImage = image }
            Divider()
            Button("Generovat znovu") { regenerate(image) }
            Button("Stáhnout…") { download(image) }
            Button("Přidat do kolekce…") { collectionTarget = image }
            Divider()
            Button("Smazat", role: .destructive) { env.library.moveToTrash(image.id) }
        }
    }

    // MARK: Generování
    private func run(_ mode: GenMode) {
        errorMessage = nil
        guard let preset = model.selectedPreset else { return }
        guard env.providers.isImplemented(preset.provider) else {
            errorMessage = "\(preset.provider.rawValue) zatím není napojený. Použij Gemini."
            return
        }
        guard let provider = env.providers.provider(for: preset.provider) else { return }
        guard let apiKey = env.providers.apiKey(for: preset.provider), !apiKey.isEmpty else {
            errorMessage = "Chybí API klíč pro \(preset.provider.rawValue). Zadej ho v Nastavení (⌘,)."
            return
        }

        let inputs = orderedInputImages()
        let runID = UUID()
        let userPrompt = model.prompt
        isGenerating = true

        Task {
            defer { isGenerating = false; statusText = nil }
            do {
                switch mode {
                case .normal:
                    statusText = "Generuji \(model.count)…"
                    let req = makeRequest(prompt: userPrompt, inputs: inputs, modelID: preset.modelID)
                    for _ in 0..<model.count {
                        try await produce(provider, req, apiKey: apiKey, label: userPrompt, runID: runID, variant: nil)
                    }

                case .variace:
                    statusText = "Variace…"
                    let req = makeRequest(prompt: userPrompt, inputs: inputs, modelID: preset.modelID)
                    for i in 1...3 {
                        try await produce(provider, req, apiKey: apiKey, label: userPrompt, runID: runID, variant: "Variace \(i)")
                    }

                case .interpretace:
                    statusText = "Interpretace…"
                    // Varianty promptu generuje vždy Gemini (jako web), obrázky pak vybraný provider.
                    guard let gemini = env.providers.provider(for: .gemini),
                          let geminiKey = env.providers.apiKey(for: .gemini), !geminiKey.isEmpty else {
                        errorMessage = "Interpretace potřebuje Gemini API klíč (generuje varianty promptu)."
                        return
                    }
                    let variants = try await gemini.promptVariants(userPrompt, apiKey: geminiKey)
                    for v in variants {
                        let req = makeRequest(prompt: v.prompt, inputs: inputs, modelID: preset.modelID)
                        try await produce(provider, req, apiKey: apiKey, label: v.prompt, runID: runID, variant: v.approach)
                    }
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Sestaví request s plným skládáním promptu (1:1 dle webu).
    private func makeRequest(prompt: String, inputs: [InputImage], modelID: String) -> GenerationRequest {
        let composed = PromptComposition.compose(.init(
            prompt: prompt,
            advanced: model.mode == .interpretace,
            advancedVariant: model.variant,
            faceIdentityMode: model.faceIdentity,
            simpleLinkMode: model.mode == .simple ? model.simpleLinkMode : nil,
            sourceImageCount: model.sourceImages.count,
            styleImageCount: model.styleImages.count,
            assetImageCount: model.assetImages.count,
            multiRefBatch: model.multiRefMode == .batch,
            styleStrength: Int(model.styleStrength),
            sourcePrompt: nil
        ))
        return GenerationRequest(
            prompt: composed.enhanced,
            inputImages: inputs,
            modelID: modelID,
            aspectRatio: model.aspectRatio.rawValue,
            resolution: model.resolution.rawValue
        )
    }

    private func produce(_ provider: AIProvider, _ req: GenerationRequest, apiKey: String,
                         label: String, runID: UUID, variant: String?,
                         replacing imageID: UUID? = nil) async throws {
        let out = try await provider.generate(req, apiKey: apiKey)
        if let imageID {
            env.library.replaceImage(
                imageID,
                imageData: out.imageData,
                prompt: label.isEmpty ? "(bez promptu)" : label,
                modelID: out.modelID,
                providerName: provider.kind.rawValue,
                aspectRatio: req.aspectRatio,
                resolution: req.resolution,
                groundingLinks: out.groundingLinks
            )
        } else {
            env.library.store(
                imageData: out.imageData,
                prompt: label.isEmpty ? "(bez promptu)" : label,
                modelID: out.modelID,
                runID: runID,
                variantLabel: variant,
                providerName: provider.kind.rawValue,
                aspectRatio: req.aspectRatio,
                resolution: req.resolution,
                groundingLinks: out.groundingLinks
            )
        }
    }

    private func regenerate(_ image: LibraryImage) {
        errorMessage = nil
        guard let preset = model.selectedPreset,
              let provider = env.providers.provider(for: preset.provider),
              let apiKey = env.providers.apiKey(for: preset.provider), !apiKey.isEmpty else {
            errorMessage = "Chybí API klíč pro \(model.selectedPreset?.provider.rawValue ?? "")."
            return
        }
        let inputs = orderedInputImages()
        let runID = UUID()
        isGenerating = true
        Task {
            defer { isGenerating = false }
            do {
                let req = makeRequest(prompt: image.prompt, inputs: inputs, modelID: preset.modelID)
                try await produce(provider, req, apiKey: apiKey, label: image.prompt, runID: runID, variant: nil)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func enhance() {
        guard !model.prompt.isEmpty, !isEnhancing else { return }
        guard let apiKey = env.providers.apiKey(for: .gemini), !apiKey.isEmpty,
              let provider = env.providers.provider(for: .gemini) else {
            errorMessage = "Chybí Gemini API klíč pro vylepšení promptu."
            return
        }
        isEnhancing = true
        Task {
            defer { isEnhancing = false }
            do { setPrompt(try await provider.enhancePrompt(model.prompt, apiKey: apiKey)) }
            catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        }
    }

    private func download(_ image: LibraryImage) {
        guard let data = image.imageData else { return }
        ImageExport.save(data, suggestedName: "mulen-\(Int(image.createdAt.timeIntervalSince1970)).png")
    }

    private func orderedInputImages() -> [InputImage] {
        (model.sourceImages + model.styleImages + model.assetImages).compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return InputImage(data: data, mimeType: mimeType(for: url))
        }
    }

    private func mimeType(for url: URL) -> String {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           let mime = type.preferredMIMEType { return mime }
        return "image/png"
    }

    private func iterate(from image: LibraryImage, prompt: String) {
        errorMessage = nil
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        let providerKind = resolvedProviderKind(for: image)
        guard let provider = env.providers.provider(for: providerKind),
              let apiKey = env.providers.apiKey(for: providerKind), !apiKey.isEmpty else {
            errorMessage = "Chybí API klíč pro \(providerKind.rawValue). Zadej ho v Nastavení (⌘,)."
            return
        }

        guard let data = try? Data(contentsOf: image.fileURL) else {
            errorMessage = "Nepodařilo se načíst zdrojový obrázek pro iteraci."
            return
        }

        let input = InputImage(data: data, mimeType: mimeType(for: image.fileURL))
        let req = GenerationRequest(
            prompt: trimmedPrompt,
            inputImages: [input],
            modelID: image.modelID,
            aspectRatio: image.aspectRatio ?? model.aspectRatio.rawValue,
            resolution: image.resolution ?? model.resolution.rawValue
        )

        isGenerating = true
        statusText = "Upravuji…"
        detailEditImageID = image.id

        Task {
            defer {
                isGenerating = false
                statusText = nil
                detailEditImageID = nil
            }
            do {
                try await produce(
                    provider,
                    req,
                    apiKey: apiKey,
                    label: trimmedPrompt,
                    runID: UUID(),
                    variant: nil,
                    replacing: image.id
                )
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func resolvedProviderKind(for image: LibraryImage) -> AIProviderKind {
        if let providerName = image.providerName,
           let direct = AIProviderKind(rawValue: providerName) {
            return direct
        }
        if image.modelID.lowercased().contains("gpt") {
            return .chatgpt
        }
        return .gemini
    }

    private var canUndoPrompt: Bool {
        promptHistory.count > 1
    }

    private var canRedoPrompt: Bool {
        !promptFuture.isEmpty
    }

    private var promptBinding: Binding<String> {
        Binding(
            get: { model.prompt },
            set: { model.prompt = $0 }
        )
    }

    private func setPrompt(_ newValue: String) {
        suppressPromptHistory = false
        model.prompt = newValue
    }

    private func undoPrompt() {
        guard canUndoPrompt else { return }
        suppressPromptHistory = true
        let current = promptHistory.removeLast()
        promptFuture.append(current)
        model.prompt = promptHistory.last ?? ""
        suppressPromptHistory = false
    }

    private func redoPrompt() {
        guard let restored = promptFuture.popLast() else { return }
        suppressPromptHistory = true
        model.prompt = restored
        promptHistory.append(restored)
        suppressPromptHistory = false
    }
}
