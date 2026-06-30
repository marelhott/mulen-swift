//
//  GenerateView.swift
//  MulenNano
//
//  Generovací pohled — 3 sloupce. Koordinuje veškerou generovací logiku (1:1 s webem):
//  generování, souběžné porovnání modelů, Variace (seed×3), šablony, kolekce a akce u výsledků.
//

import SwiftUI
import UniformTypeIdentifiers

private struct GenerationGroup: Identifiable {
    let id: UUID
    let createdAt: Date
    let images: [LibraryImage]
}

private struct GenerationSlot: Identifiable {
    let id = UUID()
    var progress: Double = 0
    var image: LibraryImage?
}

private struct PendingGeneration {
    let slotID: UUID
    let request: GenerationRequest
    let label: String
    let variant: String?
}

private struct ProviderGeneration {
    let slotID: UUID
    let request: GenerationRequest
    let label: String
    let modelLabel: String
    let provider: AIProvider
    let apiKey: String
}

private struct FluidGenerationBackground: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.82)))

                drawBlob(
                    in: &context,
                    size: size,
                    center: point(x: 0.18 + sin(time * 0.23) * 0.18,
                                  y: 0.24 + cos(time * 0.19) * 0.16,
                                  size: size),
                    color: Color(red: 0.67, green: 0.75, blue: 0.69).opacity(0.72)
                )
                drawBlob(
                    in: &context,
                    size: size,
                    center: point(x: 0.70 + cos(time * 0.17 + 1.1) * 0.17,
                                  y: 0.22 + sin(time * 0.21) * 0.15,
                                  size: size),
                    color: Color(red: 0.78, green: 0.72, blue: 0.62).opacity(0.66)
                )
                drawBlob(
                    in: &context,
                    size: size,
                    center: point(x: 0.68 + sin(time * 0.20 + 2.2) * 0.19,
                                  y: 0.72 + cos(time * 0.16 + 0.8) * 0.17,
                                  size: size),
                    color: Color(red: 0.68, green: 0.65, blue: 0.76).opacity(0.68)
                )
                drawBlob(
                    in: &context,
                    size: size,
                    center: point(x: 0.31 + cos(time * 0.18 + 2.7) * 0.18,
                                  y: 0.70 + sin(time * 0.22 + 1.4) * 0.16,
                                  size: size),
                    color: Color(red: 0.76, green: 0.65, blue: 0.66).opacity(0.55)
                )
            }
            .overlay(Color.white.opacity(0.20))
        }
    }

    private func point(x: Double, y: Double, size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    private func drawBlob(
        in context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        color: Color
    ) {
        let diameter = max(size.width, size.height) * 1.05
        let rect = CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: min(size.width, size.height) * 0.20))
            layer.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}

struct GenerateView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = GenerateModel()

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var statusText: String?
    @State private var generationProgressCurrent: Double = 0
    @State private var generationProgressTotal: Double = 1
    @State private var generationSlots: [GenerationSlot] = []

    @State private var showTemplates = false
    @State private var showSavePrompt = false
    @State private var showManagePrompts = false
    @State private var detailImage: LibraryImage?
    @State private var detailEditImageID: UUID?
    @State private var promptHistory: [String] = [""]
    @State private var promptFuture: [String] = []
    @State private var suppressPromptHistory = false
    @State private var thumbnailSize: Double = {
        guard let stored = (UserDefaults.standard.object(forKey: "generate.thumbnailSize") as? NSNumber)?.doubleValue else {
            return 272
        }
        return abs(stored - 320) < 0.5 ? 272 : stored
    }()

    private let defaultThumbnailSize = 272.0
    private let thumbnailRange = 220.0...760.0

    private var grid: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize), spacing: DS.Space.m)]
    }

    private func grid(for itemCount: Int) -> [GridItem] {
        guard itemCount == 3 else { return grid }
        return Array(
            repeating: GridItem(.flexible(minimum: 120, maximum: thumbnailSize), spacing: DS.Space.m),
            count: 3
        )
    }

    private enum GenMode { case normal, variace }

    var body: some View {
        ZStack {
            workspace

            if let detailImage {
                detailOverlay(detailImage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showTemplates) {
            TemplatesSheet { model.prompt = $0 }
        }
        .sheet(isPresented: $showSavePrompt) {
            SavePromptSheet(prompt: model.prompt)
        }
        .sheet(isPresented: $showManagePrompts) {
            ManagePromptsSheet { setPrompt($0) }
                .environment(env)
        }
        .onAppear {
            if promptHistory == [""] {
                promptHistory = [model.prompt]
            }
            thumbnailSize = min(
                thumbnailRange.upperBound,
                max(thumbnailRange.lowerBound, thumbnailSize)
            )
            UserDefaults.standard.set(thumbnailSize, forKey: "generate.thumbnailSize")
        }
        .onChange(of: thumbnailSize) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "generate.thumbnailSize")
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

    private var workspace: some View {
        HStack(spacing: 0) {
            GenerateLeftPanel(
                model: model,
                promptText: promptBinding,
                busy: isGenerating,
                savedPrompts: env.savedPrompts.prompts,
                canUndoPrompt: canUndoPrompt,
                canRedoPrompt: canRedoPrompt,
                onGenerate: { run(.normal) },
                onMultiModel: runMultiModel,
                onVariace: { run(.variace) },
                onTemplates: { showTemplates = true },
                onSavePrompt: { showSavePrompt = true },
                onManagePrompts: { showManagePrompts = true },
                onPickSaved: { setPrompt($0) },
                onUndoPrompt: undoPrompt,
                onRedoPrompt: redoPrompt
            )
            Rectangle()
                .fill(.primary.opacity(0.06))
                .frame(width: 1)
                .ignoresSafeArea()
            results
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle()
                .fill(.primary.opacity(0.06))
                .frame(width: 1)
                .ignoresSafeArea()
            GenerateRightPanel(model: model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Střed — výsledky
    private var results: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel("Výsledky generování")
                Spacer()
                thumbnailSizeControl
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
                    LazyVStack(alignment: .leading, spacing: DS.Space.xl) {
                        if !pendingGenerationSlots.isEmpty {
                            LazyVGrid(
                                columns: grid(for: pendingGenerationSlots.count),
                                alignment: .leading,
                                spacing: DS.Space.m
                            ) {
                                ForEach(pendingGenerationSlots) { slot in
                                    generationSlotTile(slot)
                                }
                            }
                        }
                        ForEach(generationGroups) { group in
                            generationRow(group)
                        }
                    }
                    .padding(DS.Space.xl)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
    }

    private var thumbnailSizeControl: some View {
        CompactScaleControl(
            value: $thumbnailSize,
            range: thumbnailRange,
            step: 32,
            help: "Změnit velikost náhledů"
        )
        .accessibilityLabel("Velikost náhledů")
    }

    private var generationGroups: [GenerationGroup] {
        var grouped: [UUID: [LibraryImage]] = [:]

        for image in env.library.images {
            let groupID = image.runID ?? image.id
            grouped[groupID, default: []].append(image)
        }

        return grouped.compactMap { id, images in
            guard let createdAt = images.map(\.createdAt).min() else { return nil }
            return GenerationGroup(
                id: id,
                createdAt: createdAt,
                images: images.sorted { $0.createdAt < $1.createdAt }
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private var pendingGenerationSlots: [GenerationSlot] {
        generationSlots.filter { $0.image == nil }
    }

    private func generationRow(_ group: GenerationGroup) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.s) {
                Text(group.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.dsSmall)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    deleteGeneration(group)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .font(.dsSmall)
                .foregroundStyle(.tertiary)
                .help("Smazat celou generaci")

                Spacer(minLength: 0)
            }

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: DS.Space.m) {
                    ForEach(group.images) { image in
                        resultTile(image)
                            .frame(width: thumbnailSize)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
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

    @ViewBuilder
    private func generationSlotTile(_ slot: GenerationSlot) -> some View {
        if let image = slot.image {
            resultTile(image)
                .transition(.opacity)
        } else {
            FluidGenerationBackground()
                .aspectRatio(generationPreviewAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                .overlay {
                    VStack(spacing: DS.Space.m) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .tint(Color.black.opacity(0.58))

                        HStack(spacing: DS.Space.s) {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.black.opacity(0.10))
                                    Capsule()
                                        .fill(Color(red: 0.24, green: 0.65, blue: 0.43))
                                        .frame(width: proxy.size.width * slot.progress)
                                }
                            }
                            .frame(height: 3)

                            Text("\(Int(slot.progress * 100)) %")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color.black.opacity(0.68))
                                .frame(width: 34, alignment: .trailing)
                        }
                        .frame(maxWidth: 150)
                    }
                }
                .transition(.opacity)
        }
    }

    private var generationPreviewAspectRatio: CGFloat {
        if let sourceURL = model.sourceImages.first,
           let sourceImage = NSImage(contentsOf: sourceURL),
           sourceImage.size.height > 0 {
            return sourceImage.size.width / sourceImage.size.height
        }

        let components = model.aspectRatio.rawValue.split(separator: ":")
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]),
              height > 0 else { return 1 }
        return width / height
    }

    private func resultTile(_ image: LibraryImage) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if let nsImage = image.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        if let label = image.variantLabel {
                            Text(label)
                                .font(.dsSmallSemibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button(role: .destructive) {
                            env.library.moveToTrash(image.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Smazat")
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
        .onTapGesture(count: 2) { detailImage = image }
        .onTapGesture(count: 1) { detailImage = image }
        .contextMenu {
            Button("Detail…") { detailImage = image }
            Divider()
            Button("Generovat znovu") { regenerate(image) }
            Button("Stáhnout…") { download(image) }
            Button("Smazat", role: .destructive) { env.library.moveToTrash(image.id) }
        }
    }

    private func deleteGeneration(_ group: GenerationGroup) {
        if let detailImage, group.images.contains(where: { $0.id == detailImage.id }) {
            self.detailImage = nil
        }
        env.library.moveToTrash(Set(group.images.map(\.id)))
    }

    private func detailOverlay(_ image: LibraryImage) -> some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { closeDetail() }

            GeneratedImageDetailSheet(
                image: image,
                busy: detailEditImageID == image.id && isGenerating,
                errorMessage: errorMessage,
                onRegenerate: { iterate(from: image, prompt: $0) },
                onDownload: { download(image) },
                onDelete: {
                    env.library.moveToTrash(image.id)
                    closeDetail()
                },
                onUndo: { env.library.undoLastRevision(image.id) },
                onRedo: { env.library.redoLastRevision(image.id) },
                onClose: closeDetail
            )
            .environment(env)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.14), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture { }
            .padding(24)
        }
        .zIndex(10)
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
    }

    private func closeDetail() {
        withAnimation(.easeOut(duration: 0.16)) {
            detailImage = nil
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
        configureProgress(for: mode)

        Task {
            defer {
                isGenerating = false
                statusText = nil
                generationSlots.removeAll()
                resetProgress()
            }
            do {
                switch mode {
                case .normal:
                    statusText = "Generuji \(model.count)…"
                    let req = makeRequest(prompt: userPrompt, inputs: inputs, modelID: preset.modelID)
                    let jobs = generationSlots.map {
                        PendingGeneration(slotID: $0.id, request: req, label: userPrompt, variant: nil)
                    }
                    try await produceConcurrently(jobs, provider: provider, apiKey: apiKey, runID: runID)

                case .variace:
                    statusText = "Variace…"
                    let req = makeRequest(prompt: userPrompt, inputs: inputs, modelID: preset.modelID)
                    let jobs = generationSlots.enumerated().map { index, slot in
                        PendingGeneration(
                            slotID: slot.id,
                            request: req,
                            label: userPrompt,
                            variant: "Variace \(index + 1)"
                        )
                    }
                    try await produceConcurrently(jobs, provider: provider, apiKey: apiKey, runID: runID)

                }
                try? await Task.sleep(for: .milliseconds(250))
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func runMultiModel() {
        errorMessage = nil

        let specs: [(id: String, label: String)] = [
            ("nano-pro", "Gemini 3 Pro"),
            ("nano-2", "Gemini 3.1 Flash"),
            ("gpt-img", "GPT Image 2"),
        ]
        let presets = specs.compactMap { spec in
            ModelPreset.all.first(where: { $0.id == spec.id }).map { (preset: $0, label: spec.label) }
        }
        guard presets.count == specs.count else {
            errorMessage = "Konfigurace více modelů není kompletní."
            return
        }

        let missingProviders = Set(presets.compactMap { target -> AIProviderKind? in
            let kind = target.preset.provider
            guard env.providers.provider(for: kind) != nil,
                  let key = env.providers.apiKey(for: kind), !key.isEmpty else { return kind }
            return nil
        })
        guard missingProviders.isEmpty else {
            let names = missingProviders.map(\.rawValue).sorted().joined(separator: " a ")
            errorMessage = "Více modelů vyžaduje API klíč pro \(names). Zadej ho v Nastavení (⌘,)."
            return
        }

        let inputs = orderedInputImages()
        let userPrompt = model.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePrompt = userPrompt.isEmpty
            ? "Create a distinct high-quality variation of the provided image. Preserve the main subject, identity, composition, and visual intent while varying secondary details naturally."
            : userPrompt
        let runID = UUID()

        isGenerating = true
        statusText = "Více modelů…"
        generationProgressCurrent = 0
        generationProgressTotal = 3
        prepareGenerationSlots(count: 3)

        let jobs = zip(generationSlots, presets).compactMap { slot, target -> ProviderGeneration? in
            guard let provider = env.providers.provider(for: target.preset.provider),
                  let apiKey = env.providers.apiKey(for: target.preset.provider), !apiKey.isEmpty else { return nil }
            var request = makeRequest(prompt: effectivePrompt, inputs: inputs, modelID: target.preset.modelID)
            request.allowModelFallback = false
            return ProviderGeneration(
                slotID: slot.id,
                request: request,
                label: userPrompt,
                modelLabel: target.label,
                provider: provider,
                apiKey: apiKey
            )
        }

        Task {
            defer {
                isGenerating = false
                statusText = nil
                generationSlots.removeAll()
                resetProgress()
            }
            do {
                try await produceAcrossModels(jobs, runID: runID)
                try? await Task.sleep(for: .milliseconds(250))
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
                         replacing imageID: UUID? = nil) async throws -> LibraryImage? {
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
            return nil
        } else {
            return env.library.store(
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

    private func produceConcurrently(
        _ jobs: [PendingGeneration],
        provider: AIProvider,
        apiKey: String,
        runID: UUID
    ) async throws {
        let tasks = jobs.map { job in
            Task { @MainActor in
                let progressTask = estimatedProgressTask(for: job.slotID)
                defer { progressTask.cancel() }

                let image = try await produceWithNoImageRetry(
                    provider,
                    job.request,
                    apiKey: apiKey,
                    label: job.label,
                    runID: runID,
                    variant: job.variant
                )
                completeGenerationSlot(job.slotID, with: image)
                advanceProgress()
            }
        }

        var firstError: Error?
        for task in tasks {
            do {
                try await task.value
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }

    private func produceAcrossModels(_ jobs: [ProviderGeneration], runID: UUID) async throws {
        let tasks = jobs.map { job in
            Task { @MainActor in
                let progressTask = estimatedProgressTask(for: job.slotID)
                defer { progressTask.cancel() }

                let image = try await produceWithNoImageRetry(
                    job.provider,
                    job.request,
                    apiKey: job.apiKey,
                    label: job.label,
                    runID: runID,
                    variant: job.modelLabel
                )
                completeGenerationSlot(job.slotID, with: image)
                advanceProgress()
            }
        }

        var firstError: Error?
        for task in tasks {
            do {
                try await task.value
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }

    private func produceWithNoImageRetry(
        _ provider: AIProvider,
        _ request: GenerationRequest,
        apiKey: String,
        label: String,
        runID: UUID,
        variant: String?
    ) async throws -> LibraryImage? {
        if provider.kind == .gemini {
            return try await produce(
                provider,
                request,
                apiKey: apiKey,
                label: label,
                runID: runID,
                variant: variant
            )
        }

        do {
            return try await produce(
                provider,
                request,
                apiKey: apiKey,
                label: label,
                runID: runID,
                variant: variant
            )
        } catch ProviderError.noImageInResponse {
            try await Task.sleep(for: .milliseconds(450))
            return try await produce(
                provider,
                request,
                apiKey: apiKey,
                label: label,
                runID: runID,
                variant: variant
            )
        }
    }

    private func estimatedProgressTask(for slotID: UUID) -> Task<Void, Never> {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled,
                      let index = generationSlots.firstIndex(where: { $0.id == slotID }) else { return }
                let remaining = 0.92 - generationSlots[index].progress
                generationSlots[index].progress += max(0.003, remaining * 0.035)
                generationSlots[index].progress = min(generationSlots[index].progress, 0.92)
            }
        }
    }

    private func completeGenerationSlot(_ slotID: UUID, with image: LibraryImage?) {
        guard let index = generationSlots.firstIndex(where: { $0.id == slotID }) else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            generationSlots[index].progress = 1
            generationSlots[index].image = image
        }
    }

    private func prepareGenerationSlots(count: Int) {
        generationSlots = (0..<max(count, 0)).map { _ in GenerationSlot() }
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
        generationProgressCurrent = 0
        generationProgressTotal = 1
        Task {
            defer {
                isGenerating = false
                resetProgress()
            }
            do {
                let req = makeRequest(prompt: image.prompt, inputs: inputs, modelID: preset.modelID)
                _ = try await produce(provider, req, apiKey: apiKey, label: image.prompt, runID: runID, variant: nil)
                advanceProgress()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
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
        generationProgressCurrent = 0
        generationProgressTotal = 1

        Task {
            defer {
                isGenerating = false
                statusText = nil
                detailEditImageID = nil
                resetProgress()
            }
            do {
                _ = try await produce(
                    provider,
                    req,
                    apiKey: apiKey,
                    label: trimmedPrompt,
                    runID: UUID(),
                    variant: nil,
                    replacing: image.id
                )
                advanceProgress()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func configureProgress(for mode: GenMode) {
        generationProgressCurrent = 0
        switch mode {
        case .normal:
            generationProgressTotal = Double(max(model.count, 1))
            prepareGenerationSlots(count: max(model.count, 1))
        case .variace:
            generationProgressTotal = 3
            prepareGenerationSlots(count: 3)
        }
    }

    private func advanceProgress() {
        generationProgressCurrent = min(generationProgressCurrent + 1, generationProgressTotal)
    }

    private func resetProgress() {
        generationProgressCurrent = 0
        generationProgressTotal = 1
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
