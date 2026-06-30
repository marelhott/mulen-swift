//
//  ToolViews.swift
//  MulenNano
//
//  Obrazovky nástrojů: Reframe, Batch, Face Swap, AI Upscaler.
//

import SwiftUI

private enum UpscalerOutputStatus {
    case pending
    case running
    case retrying
    case done
    case error
}

private struct UpscalerOutput: Identifiable {
    let id: String
    let inputURL: URL
    let inputName: String
    let branch: UpscaleBranch
    let mode: UpscaleMode?
    let faithfulModel: UpscaleModelChoice?
    let creativePreset: CreativeUpscalePreset?
    let scale: UpscaleScale
    let providerKind: AIProviderKind
    let createdAt: Date
    var status: UpscalerOutputStatus
    var detailText: String
    var image: LibraryImage?
    var error: String?
    var attempt: Int = 0
    var resultWidth: Int?
    var resultHeight: Int?
}

private enum FaceSwapOutputStatus: Equatable {
    case pending
    case running
    case retrying
    case done
    case error
}

private struct FaceSwapOutput: Identifiable {
    let id: UUID
    let runID: UUID
    let createdAt: Date
    let model: FaceSwapPromptModel
    let mode: FaceSwapMode
    let batchIndex: Int
    let batchTotal: Int
    var status: FaceSwapOutputStatus
    var progress: Double
    var image: LibraryImage?
    var error: String?
    var resultWidth: Int?
    var resultHeight: Int?
}

private enum ToolJobStatus: Equatable {
    case pending, running, retrying, done, error
}

private struct ReframeOutput: Identifiable {
    let id: UUID
    let runID: UUID
    let createdAt: Date
    let perspective: ReframePerspective
    let resolution: ResolutionOption
    var status: ToolJobStatus
    var progress: Double
    var image: LibraryImage?
    var error: String?
    var resultWidth: Int?
    var resultHeight: Int?
}

private struct BatchOutput: Identifiable {
    let id: UUID
    let runID: UUID
    let createdAt: Date
    let inputURL: URL
    let inputName: String
    let variantIndex: Int
    let variantTotal: Int
    let presetTitle: String
    let prompt: String
    let model: BatchModelChoice
    var status: ToolJobStatus
    var progress: Double
    var image: LibraryImage?
    var error: String?
    var resultWidth: Int?
    var resultHeight: Int?
}

// MARK: - Reframe
struct ReframeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var images: [URL] = []
    @State private var selected: Set<String> = ["closeup", "long-shot", "low-angle", "high-angle"]
    @State private var resolution: ResolutionOption = .twoK
    @State private var outputs: [ReframeOutput] = []
    @State private var busy = false
    @State private var error: String?
    @State private var activeConcurrency = 1

    private let chips = [GridItem(.adaptive(minimum: 92), spacing: DS.Space.xs)]

    var body: some View {
        ToolSplitScaffold(
            runLabel: "Reframe • \(selected.count) perspektiv",
            canRun: !images.isEmpty && !selected.isEmpty && !busy,
            busy: busy,
            error: error
        ) {
            ImageWell(title: "Vstupní obrázek", urls: $images, maxCount: 1)

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Perspektivy")
                LazyVGrid(columns: chips, alignment: .leading, spacing: DS.Space.xs) {
                    ForEach(ReframePerspective.all) { perspective in
                        Chip(label: perspective.label, active: selected.contains(perspective.id)) {
                            if selected.contains(perspective.id) {
                                selected.remove(perspective.id)
                            } else {
                                selected.insert(perspective.id)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Rozlišení")
                CapsuleSegmentedPicker(
                    title: "Reframe resolution",
                    options: [ResolutionOption.oneK, .twoK].map { ($0, $0.rawValue) },
                    selection: $resolution
                )
                Text("Gemini 3 Pro • zachová poměr stran vstupu")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
            }

            if !outputs.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    Hairline()
                    SectionLabel("Stav úlohy")
                    statusRow("Souběh", value: "\(activeConcurrency)")
                    statusRow("Běží", value: "\(runningCount)")
                    statusRow("Hotovo", value: "\(doneCount)")
                    statusRow("Chyby", value: "\(errorCount)")
                }
            }
        } results: {
            results
        } onRun: {
            run()
        }
    }

    private func run() {
        guard let url = images.first else { return }
        guard env.providers.hasKey(for: .gemini) else {
            error = "Chybí Gemini API klíč. Zadej ho v Nastavení (⌘,)."
            return
        }
        let engine = ToolEngine(env: env)
        guard let input = engine.loadInput(url) else {
            error = "Nepodařilo se načíst vstupní obrázek."
            return
        }
        let picked = ReframePerspective.all.filter { selected.contains($0.id) }
        let runID = UUID()
        let createdAt = Date()
        let selectedResolution = resolution
        let jobs = picked.enumerated().map { index, perspective in
            ReframeOutput(
                id: UUID(),
                runID: runID,
                createdAt: createdAt.addingTimeInterval(Double(index) / 1000),
                perspective: perspective,
                resolution: selectedResolution,
                status: .pending,
                progress: 0
            )
        }
        let ratio = toolAspectRatio(for: input.data)
        activeConcurrency = input.data.count > 4_500_000 ? 1 : min(3, jobs.count)
        outputs.insert(contentsOf: jobs, at: 0)
        busy = true
        error = nil

        Task { @MainActor in
            for start in stride(from: 0, to: jobs.count, by: activeConcurrency) {
                let chunk = Array(jobs[start..<min(start + activeConcurrency, jobs.count)])
                await withTaskGroup(of: Void.self) { group in
                    for job in chunk {
                        group.addTask {
                            await runSingle(job, input: input, aspectRatio: ratio, engine: engine)
                        }
                    }
                }
            }
            busy = false
            let currentRun = outputs.filter { $0.runID == runID }
            if !currentRun.contains(where: { $0.status == .done }) {
                error = currentRun.compactMap(\.error).first ?? "Reframe selhal."
            }
        }
    }

    @MainActor
    private func runSingle(_ job: ReframeOutput, input: InputImage, aspectRatio: String, engine: ToolEngine) async {
        let progressTask = estimatedProgressTask(for: job.id)
        defer { progressTask.cancel() }

        for attempt in 1...3 {
            update(job.id) {
                $0.status = attempt == 1 ? .running : .retrying
                $0.error = nil
            }
            do {
                let generated = try await engine.generateOutput(
                    inputs: [input],
                    prompt: job.perspective.fullPrompt(aspectRatio: aspectRatio),
                    providerKind: .gemini,
                    modelID: "gemini-3-pro-image",
                    resolution: job.resolution.rawValue
                )
                let stored = env.library.store(
                    imageData: generated.imageData,
                    prompt: "Reframe: \(job.perspective.label)",
                    modelID: generated.modelID,
                    runID: job.runID,
                    variantLabel: job.perspective.label,
                    providerName: AIProviderKind.gemini.rawValue,
                    aspectRatio: aspectRatio,
                    resolution: job.resolution.rawValue
                )
                let dimensions = ToolEngine.pixelSize(for: generated.imageData)
                update(job.id) {
                    $0.status = .done
                    $0.progress = 1
                    $0.image = stored
                    $0.resultWidth = dimensions?.width
                    $0.resultHeight = dimensions?.height
                }
                return
            } catch {
                if attempt < 3 {
                    try? await Task.sleep(for: .milliseconds(450 * attempt))
                } else {
                    update(job.id) {
                        $0.status = .error
                        $0.progress = 1
                        $0.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    }
                }
            }
        }
    }

    private var results: some View {
        Group {
            if outputs.isEmpty {
                LibraryEmptyState(
                    systemImage: "camera.viewfinder",
                    title: "Připraveno na Reframe",
                    subtitle: "Vyber vstup a požadované úhly kamery vlevo."
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 340), spacing: DS.Space.m, alignment: .top)],
                        alignment: .leading,
                        spacing: DS.Space.l
                    ) {
                        ForEach(outputs.sorted { $0.createdAt > $1.createdAt }) { output in
                            ToolJobCard(
                                status: output.status,
                                progress: output.progress,
                                image: output.image,
                                title: output.perspective.label,
                                detail: detail(output),
                                error: output.error,
                                workingLabel: "Měním perspektivu…",
                                onDownload: { if let image = output.image { toolDownload(image, prefix: "mulen-reframe") } },
                                onDelete: { delete(output) }
                            )
                        }
                    }
                    .padding(DS.Space.l)
                }
            }
        }
    }

    private func estimatedProgressTask(for id: UUID) -> Task<Void, Never> {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(180))
                guard let index = outputs.firstIndex(where: { $0.id == id }),
                      outputs[index].status == .running || outputs[index].status == .retrying else { return }
                let remaining = 0.92 - outputs[index].progress
                outputs[index].progress = min(0.92, outputs[index].progress + max(0.003, remaining * 0.035))
            }
        }
    }

    private func update(_ id: UUID, mutate: (inout ReframeOutput) -> Void) {
        guard let index = outputs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&outputs[index])
    }

    private func delete(_ output: ReframeOutput) {
        if let image = output.image { env.library.moveToTrash(image.id) }
        outputs.removeAll { $0.id == output.id }
    }

    private func detail(_ output: ReframeOutput) -> String {
        guard let width = output.resultWidth, let height = output.resultHeight else {
            return "Gemini 3 Pro • \(output.resolution.rawValue)"
        }
        return "Gemini 3 Pro • \(width)×\(height)"
    }

    private var runningCount: Int { outputs.filter { $0.status == .running || $0.status == .retrying }.count }
    private var doneCount: Int { outputs.filter { $0.status == .done }.count }
    private var errorCount: Int { outputs.filter { $0.status == .error }.count }

    private func statusRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.dsCaption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.dsValue)
        }
    }
}

// MARK: - Batch
struct BatchView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var images: [URL] = []
    @State private var preset: BatchPreset = BatchPreset.all[0]
    @State private var custom = ""
    @State private var variants = 1
    @State private var model: BatchModelChoice = .nanoPro
    @State private var outputs: [BatchOutput] = []
    @State private var busy = false
    @State private var error: String?
    @State private var activeConcurrency = 1

    var body: some View {
        ToolSplitScaffold(
            runLabel: "Batch • \(images.count * variants) výstupů",
            canRun: !images.isEmpty && !busy,
            busy: busy,
            error: error
        ) {
            ImageWell(title: "Vstupní obrázky", urls: $images)

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Preset")
                CapsuleSegmentedPicker(
                    title: "Batch preset",
                    options: BatchPreset.all.map { ($0, $0.label) },
                    selection: $preset
                )
                Text(preset.title).font(.dsCaption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Doplňující instrukce")
                TextField("volitelné…", text: $custom, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Varianty na vstup")
                CapsuleSegmentedPicker(
                    title: "Batch variants",
                    options: (1...5).map { ($0, "\($0)") },
                    selection: $variants
                )
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Model")
                CapsuleSegmentedPicker(
                    title: "Batch model",
                    options: BatchModelChoice.allCases.map { ($0, $0.title) },
                    selection: $model
                )
                Text(model.subtitle).font(.dsCaption).foregroundStyle(.secondary)
            }

            if !outputs.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    Hairline()
                    SectionLabel("Stav dávky")
                    statusRow("Souběh", value: "\(activeConcurrency)")
                    statusRow("Běží", value: "\(runningCount)")
                    statusRow("Hotovo", value: "\(doneCount)")
                    statusRow("Chyby", value: "\(errorCount)")
                    if errorCount > 0 && !busy {
                        Button("Opakovat \(errorCount) selhání") { retryFailed() }
                            .controlSize(.small)
                    }
                }
            }
        } results: {
            results
        } onRun: {
            run()
        }
    }

    private func run() {
        guard env.providers.hasKey(for: model.provider) else {
            error = "Chybí \(model.provider.rawValue) API klíč. Zadej ho v Nastavení (⌘,)."
            return
        }
        let engine = ToolEngine(env: env)
        let runID = UUID()
        let createdAt = Date()
        let basePrompt = BatchPreset.buildPrompt(preset, custom: custom)
        let selectedModel = model
        let selectedPreset = preset
        var order = 0
        let jobs = images.flatMap { url in
            (0..<variants).map { variantIndex -> BatchOutput in
                defer { order += 1 }
                let prompt = variants <= 1 ? basePrompt : "\(basePrompt)\n\nVytvoř variantu \(variantIndex + 1) z \(variants). Zachovej hlavní zadání, ale nabídni jemně odlišné řešení v detailu, světle, materiálovém čtení nebo kompozici. Výsledek musí zůstat přirozený a uvěřitelný."
                return BatchOutput(
                    id: UUID(),
                    runID: runID,
                    createdAt: createdAt.addingTimeInterval(Double(order) / 1000),
                    inputURL: url,
                    inputName: url.lastPathComponent,
                    variantIndex: variantIndex,
                    variantTotal: variants,
                    presetTitle: selectedPreset.title,
                    prompt: prompt,
                    model: selectedModel,
                    status: .pending,
                    progress: 0
                )
            }
        }
        activeConcurrency = concurrency(for: images, jobCount: jobs.count)
        outputs.insert(contentsOf: jobs, at: 0)
        busy = true
        error = nil

        Task { @MainActor in
            await process(jobs, engine: engine)
            busy = false
            let currentRun = outputs.filter { $0.runID == runID }
            if !currentRun.contains(where: { $0.status == .done }) {
                error = currentRun.compactMap(\.error).first ?? "Batch selhal."
            }
        }
    }

    private func retryFailed() {
        let failed = outputs.filter { $0.status == .error }
        guard !failed.isEmpty else { return }
        let missingProviders = Set(failed.map(\.model.provider)).filter { !env.providers.hasKey(for: $0) }
        guard missingProviders.isEmpty else {
            error = "Chybí API klíč pro \(missingProviders.map(\.rawValue).sorted().joined(separator: " a "))."
            return
        }
        let engine = ToolEngine(env: env)
        for job in failed {
            update(job.id) { $0.status = .pending; $0.progress = 0; $0.error = nil }
        }
        activeConcurrency = concurrency(for: failed.map(\.inputURL), jobCount: failed.count)
        busy = true
        error = nil
        Task { @MainActor in
            await process(failed, engine: engine)
            busy = false
        }
    }

    @MainActor
    private func process(_ jobs: [BatchOutput], engine: ToolEngine) async {
        for start in stride(from: 0, to: jobs.count, by: activeConcurrency) {
            let chunk = Array(jobs[start..<min(start + activeConcurrency, jobs.count)])
            await withTaskGroup(of: Void.self) { group in
                for job in chunk {
                    group.addTask {
                        await runSingle(job, engine: engine)
                    }
                }
            }
        }
    }

    @MainActor
    private func runSingle(_ job: BatchOutput, engine: ToolEngine) async {
        guard let input = engine.loadInput(job.inputURL) else {
            update(job.id) { $0.status = .error; $0.progress = 1; $0.error = "Nepodařilo se načíst vstupní obrázek." }
            return
        }
        let progressTask = estimatedProgressTask(for: job.id)
        defer { progressTask.cancel() }

        for attempt in 1...3 {
            update(job.id) {
                $0.status = attempt == 1 ? .running : .retrying
                $0.error = nil
            }
            do {
                let generated = try await engine.generateOutput(
                    inputs: [input],
                    prompt: job.prompt,
                    providerKind: job.model.provider,
                    modelID: job.model.modelID,
                    resolution: "1K"
                )
                let ratio = toolAspectRatio(for: input.data)
                let variant = "\(job.inputName) • Varianta \(job.variantIndex + 1)/\(job.variantTotal) • \(job.model.title)"
                let stored = env.library.store(
                    imageData: generated.imageData,
                    prompt: job.presetTitle,
                    modelID: generated.modelID,
                    runID: job.runID,
                    variantLabel: variant,
                    providerName: job.model.provider.rawValue,
                    aspectRatio: ratio,
                    resolution: "1K"
                )
                let dimensions = ToolEngine.pixelSize(for: generated.imageData)
                update(job.id) {
                    $0.status = .done
                    $0.progress = 1
                    $0.image = stored
                    $0.resultWidth = dimensions?.width
                    $0.resultHeight = dimensions?.height
                }
                return
            } catch {
                if attempt < 3 {
                    try? await Task.sleep(for: .milliseconds(450 * attempt))
                } else {
                    update(job.id) {
                        $0.status = .error
                        $0.progress = 1
                        $0.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    }
                }
            }
        }
    }

    private var results: some View {
        Group {
            if outputs.isEmpty {
                LibraryEmptyState(
                    systemImage: "square.grid.2x2",
                    title: "Připraveno na Batch",
                    subtitle: "Vlož více obrázků a nastav společný způsob zpracování vlevo."
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 340), spacing: DS.Space.m, alignment: .top)],
                        alignment: .leading,
                        spacing: DS.Space.l
                    ) {
                        ForEach(outputs.sorted { $0.createdAt > $1.createdAt }) { output in
                            ToolJobCard(
                                status: output.status,
                                progress: output.progress,
                                image: output.image,
                                title: "\(output.inputName) • \(output.variantIndex + 1)",
                                detail: detail(output),
                                error: output.error,
                                workingLabel: "Zpracovávám dávku…",
                                onDownload: { if let image = output.image { toolDownload(image, prefix: "mulen-batch") } },
                                onDelete: { delete(output) }
                            )
                        }
                    }
                    .padding(DS.Space.l)
                }
            }
        }
    }

    private func estimatedProgressTask(for id: UUID) -> Task<Void, Never> {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(180))
                guard let index = outputs.firstIndex(where: { $0.id == id }),
                      outputs[index].status == .running || outputs[index].status == .retrying else { return }
                let remaining = 0.92 - outputs[index].progress
                outputs[index].progress = min(0.92, outputs[index].progress + max(0.003, remaining * 0.035))
            }
        }
    }

    private func update(_ id: UUID, mutate: (inout BatchOutput) -> Void) {
        guard let index = outputs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&outputs[index])
    }

    private func delete(_ output: BatchOutput) {
        if let image = output.image { env.library.moveToTrash(image.id) }
        outputs.removeAll { $0.id == output.id }
    }

    private func concurrency(for urls: [URL], jobCount: Int) -> Int {
        let sizes = urls.compactMap { try? Data(contentsOf: $0).count }.map { Double($0) / 1_048_576 }
        let average = sizes.isEmpty ? 0 : sizes.reduce(0, +) / Double(sizes.count)
        return (sizes.max() ?? 0) > 4.5 || average > 3 ? 1 : min(2, max(1, jobCount))
    }

    private func detail(_ output: BatchOutput) -> String {
        guard let width = output.resultWidth, let height = output.resultHeight else {
            return "\(output.model.title) • 1K"
        }
        return "\(output.model.title) • \(width)×\(height)"
    }

    private var runningCount: Int { outputs.filter { $0.status == .running || $0.status == .retrying }.count }
    private var doneCount: Int { outputs.filter { $0.status == .done }.count }
    private var errorCount: Int { outputs.filter { $0.status == .error }.count }

    private func statusRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.dsCaption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.dsValue)
        }
    }
}

// MARK: - Face Swap
struct FaceSwapView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var targetImages: [URL] = []
    @State private var sourceImages: [URL] = []
    @State private var mode: FaceSwapMode = .head
    @State private var modelChoice: FaceSwapModelChoice = .both
    @State private var outputCount = 2
    @State private var hairSource: FaceSwapHairSource = .target
    @State private var gender: FaceSwapGender = .automatic
    @State private var outputs: [FaceSwapOutput] = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ToolSplitScaffold(
            runLabel: busy ? "Provádím swap…" : "Spustit \(mode.title) • \(plannedJobCount) výstupů",
            canRun: !targetImages.isEmpty && !sourceImages.isEmpty && !busy,
            busy: busy,
            error: error
        ) {
            ImageWell(
                title: "Cíl",
                urls: $targetImages,
                hint: "Fotografie a scéna, která zůstane zachována.",
                maxCount: 1
            )
            ImageWell(
                title: "Zdroj identity",
                urls: $sourceImages,
                hint: "Člověk, jehož obličej nebo hlava se přenese do cíle.",
                maxCount: 1
            )

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Rozsah")
                CapsuleSegmentedPicker(
                    title: "Rozsah výměny",
                    options: FaceSwapMode.allCases.map { ($0, $0.rawValue) },
                    selection: $mode
                )
                Text(mode.summary)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Model")
                CapsuleSegmentedPicker(
                    title: "Modely pro Face Swap",
                    options: FaceSwapModelChoice.allCases.map { ($0, $0.title) },
                    selection: $modelChoice
                )
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Počet na model")
                CapsuleSegmentedPicker(
                    title: "Počet výstupů na model",
                    options: [1, 2, 3].map { ($0, "\($0)") },
                    selection: $outputCount
                )
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Vlasy")
                CapsuleSegmentedPicker(
                    title: "Zdroj vlasů",
                    options: FaceSwapHairSource.allCases.map { ($0, $0.title) },
                    selection: $hairSource
                )
                Text(hairSource == .source
                     ? "Přenese také účes, vlasovou linii a barvu vlasů ze zdroje."
                     : "Drží siluetu a napojení vlasů z cílové fotografie.")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Gender kontext")
                Picker("", selection: $gender) {
                    ForEach(FaceSwapGender.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            }

            if !outputs.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    Hairline()
                    SectionLabel("Stav úlohy")
                    statusRow("Celkem", value: "\(outputs.count)")
                    statusRow("Běží", value: "\(runningCount)")
                    statusRow("Hotovo", value: "\(doneCount)")
                    statusRow("Chyby", value: "\(errorCount)")
                }
            }
        } results: {
            results
        } onRun: {
            run()
        }
    }

    private func run() {
        guard let targetURL = targetImages.first, let sourceURL = sourceImages.first,
              let targetData = try? Data(contentsOf: targetURL),
              let sourceData = try? Data(contentsOf: sourceURL),
              let composite = ToolImage.composite(targetData: targetData, sourceData: sourceData) else {
            error = "Nepodařilo se připravit obrázky."
            return
        }

        let models = modelChoice.models
        let missingProviders = models.filter { model in
            !env.providers.hasKey(for: model.provider)
        }
        guard missingProviders.isEmpty else {
            let names = Set(missingProviders.map { $0.provider.rawValue }).sorted().joined(separator: " a ")
            error = "Chybí API klíč pro \(names). Zadej ho v Nastavení (⌘,)."
            return
        }

        let engine = ToolEngine(env: env)
        let runID = UUID()
        let createdAt = Date()
        let newOutputs = models.flatMap { model in
            (0..<outputCount).map { batchIndex in
                FaceSwapOutput(
                    id: UUID(),
                    runID: runID,
                    createdAt: createdAt.addingTimeInterval(Double(batchIndex) / 1000),
                    model: model,
                    mode: mode,
                    batchIndex: batchIndex,
                    batchTotal: outputCount,
                    status: .pending,
                    progress: 0,
                    image: nil,
                    error: nil
                )
            }
        }

        outputs.insert(contentsOf: newOutputs, at: 0)
        busy = true
        error = nil

        let modeSnapshot = mode
        let hairSnapshot = hairSource
        let genderSnapshot = gender
        Task {
            await withTaskGroup(of: Void.self) { group in
                for output in newOutputs {
                    group.addTask {
                        await runSingleSwap(
                            output,
                            composite: composite,
                            engine: engine,
                            mode: modeSnapshot,
                            hairSource: hairSnapshot,
                            gender: genderSnapshot
                        )
                    }
                }
            }
            busy = false
            let currentRun = outputs.filter { $0.runID == runID }
            if !currentRun.contains(where: { $0.status == .done }),
               let firstFailure = currentRun.first(where: { $0.error != nil })?.error {
                error = firstFailure
            }
        }
    }

    @MainActor
    private func runSingleSwap(
        _ job: FaceSwapOutput,
        composite: InputImage,
        engine: ToolEngine,
        mode: FaceSwapMode,
        hairSource: FaceSwapHairSource,
        gender: FaceSwapGender
    ) async {
        let progressTask = estimatedProgressTask(for: job.id)
        defer { progressTask.cancel() }

        for attempt in 1...2 {
            updateOutput(job.id) { output in
                output.status = attempt == 1 ? .running : .retrying
                output.error = nil
            }

            do {
                let prompt = FaceSwapPrompt.build(
                    mode: mode,
                    model: job.model,
                    hairSource: hairSource,
                    batchIndex: job.batchIndex,
                    gender: gender
                )
                let generated = try await engine.generateOutput(
                    inputs: [composite],
                    prompt: prompt,
                    providerKind: job.model.provider,
                    modelID: job.model.modelID
                )
                let variant = "\(job.mode.title) • \(job.model.title) • \(job.batchIndex + 1)/\(job.batchTotal)"
                let stored = env.library.store(
                    imageData: generated.imageData,
                    prompt: mode.title,
                    modelID: generated.modelID,
                    runID: job.runID,
                    variantLabel: variant,
                    providerName: job.model.provider.rawValue,
                    aspectRatio: "Original",
                    resolution: "Match target"
                )
                let dimensions = ToolEngine.pixelSize(for: generated.imageData)
                updateOutput(job.id) { output in
                    output.status = .done
                    output.progress = 1
                    output.image = stored
                    output.resultWidth = dimensions?.width
                    output.resultHeight = dimensions?.height
                }
                return
            } catch {
                if attempt == 1 {
                    try? await Task.sleep(for: .milliseconds(450))
                    continue
                }
                updateOutput(job.id) { output in
                    output.status = .error
                    output.progress = 1
                    output.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private var results: some View {
        Group {
            if outputs.isEmpty {
                LibraryEmptyState(
                    systemImage: "person.crop.rectangle",
                    title: "Připraveno na Face Swap",
                    subtitle: "Vlož cílovou fotografii a zdroj identity vlevo."
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 340), spacing: DS.Space.m, alignment: .top)],
                        alignment: .leading,
                        spacing: DS.Space.l
                    ) {
                        ForEach(sortedOutputs) { output in
                            outputCard(output)
                        }
                    }
                    .padding(DS.Space.l)
                }
            }
        }
    }

    private func outputCard(_ output: FaceSwapOutput) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(DS.Palette.fieldBackground)

                switch output.status {
                case .done:
                    if let image = output.image?.nsImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .error:
                    VStack(spacing: DS.Space.s) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.red)
                        Text(output.error ?? "Swap selhal")
                            .font(.dsCaption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .padding(.horizontal, DS.Space.m)
                    }
                case .pending, .running, .retrying:
                    VStack(spacing: DS.Space.m) {
                        ProgressView()
                            .controlSize(.small)
                        Text(output.status == .retrying ? "Opakuji…" : "Provádím swap…")
                            .font(.dsSmallSemibold)
                            .foregroundStyle(.secondary)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: proxy.size.width * output.progress)
                            }
                        }
                        .frame(width: 130, height: 3)
                        Text("\(Int(output.progress * 100)) %")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(minHeight: 230)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(output.model.title) • varianta \(output.batchIndex + 1)")
                        .font(.dsSmallSemibold)
                    Text(outputDetail(output))
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Space.s)
                if let image = output.image {
                    Button {
                        download(image)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.plain)
                    .help("Stáhnout")
                }
            }
        }
        .contextMenu {
            if let image = output.image {
                Button("Stáhnout…") { download(image) }
                Button("Smazat", role: .destructive) {
                    env.library.moveToTrash(image.id)
                    updateOutput(output.id) { $0.image = nil; $0.status = .error; $0.error = "Přesunuto do koše" }
                }
            }
        }
    }

    private func estimatedProgressTask(for id: UUID) -> Task<Void, Never> {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled,
                      let index = outputs.firstIndex(where: { $0.id == id }),
                      outputs[index].status == .running || outputs[index].status == .retrying else { return }
                let remaining = 0.92 - outputs[index].progress
                outputs[index].progress = min(0.92, outputs[index].progress + max(0.003, remaining * 0.035))
            }
        }
    }

    private func updateOutput(_ id: UUID, mutate: (inout FaceSwapOutput) -> Void) {
        guard let index = outputs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&outputs[index])
    }

    private func statusRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.dsCaption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.dsValue)
        }
    }

    private func outputDetail(_ output: FaceSwapOutput) -> String {
        guard let width = output.resultWidth, let height = output.resultHeight else {
            return output.status == .error ? "Chyba" : output.mode.title
        }
        return "\(output.mode.title) • \(width)×\(height)"
    }

    private func download(_ image: LibraryImage) {
        guard let data = image.imageData else { return }
        ImageExport.save(data, suggestedName: "mulen-face-swap-\(Int(image.createdAt.timeIntervalSince1970)).png")
    }

    private var sortedOutputs: [FaceSwapOutput] {
        outputs.sorted { $0.createdAt > $1.createdAt }
    }

    private var plannedJobCount: Int {
        modelChoice.models.count * outputCount
    }

    private var runningCount: Int {
        outputs.filter { $0.status == .running || $0.status == .retrying }.count
    }

    private var doneCount: Int {
        outputs.filter { $0.status == .done }.count
    }

    private var errorCount: Int {
        outputs.filter { $0.status == .error }.count
    }
}

// MARK: - AI Upscaler
struct UpscalerView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var images: [URL] = []
    @State private var branch: UpscaleBranch = .faithful
    @State private var mode: UpscaleMode = .detailEnhance
    @State private var model: UpscaleModelChoice = .nanoPro
    @State private var creativePreset: CreativeUpscalePreset = .balanced
    @State private var scale: UpscaleScale = .x2
    @State private var outputs: [UpscalerOutput] = []
    @State private var busy = false
    @State private var error: String?
    @State private var activeConcurrency = 1
    @State private var concurrencyReason = "bez vstupu"
    @State private var batchCurrent = 0
    @State private var batchTotal = 0
    @State private var activeFileName = ""

    var body: some View {
        ToolSplitScaffold(
            runLabel: busy
                ? "\(branch.title) • pracuji…"
                : "\(currentRunTitle) \(scale.title) • \(max(1, pendingCount)) zbývá",
            canRun: !images.isEmpty && !busy,
            busy: busy,
            error: error
        ) {
            ImageWell(title: "Vstupní obrázky", urls: $images)

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Větev")
                CapsuleSegmentedPicker(
                    title: "Upscale branch",
                    options: UpscaleBranch.allCases.map { ($0, $0.title) },
                    selection: $branch
                )
                Text(branch.summary)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if branch == .faithful {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    SectionLabel("Režim")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Space.xs) {
                        ForEach(UpscaleMode.allCases) { item in
                            Button {
                                mode = item
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.dsSmallSemibold)
                                    Text(item.summary)
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(mode == item ? Color.primary.opacity(0.78) : Color.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DS.Space.s)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                                        .fill(mode == item ? Color.accentColor.opacity(0.10) : DS.Palette.fieldBackground)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                                        .stroke(mode == item ? Color.accentColor.opacity(0.28) : Color.clear, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    SectionLabel("Model")
                    CapsuleSegmentedPicker(
                        title: "Upscaler model",
                        options: UpscaleModelChoice.allCases.map { ($0, $0.title) },
                        selection: $model
                    )
                    Text(model.subtitle)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    SectionLabel("Creative preset")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Space.xs) {
                        ForEach(CreativeUpscalePreset.allCases) { item in
                            Button {
                                creativePreset = item
                            } label: {
                                VStack(spacing: 4) {
                                    Text(item.title)
                                        .font(.dsSmallSemibold)
                                    Text(item.summary)
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(creativePreset == item ? Color.primary.opacity(0.78) : Color.secondary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, DS.Space.xs)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                                        .fill(creativePreset == item ? Color.accentColor.opacity(0.10) : DS.Palette.fieldBackground)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                                        .stroke(creativePreset == item ? Color.accentColor.opacity(0.28) : Color.clear, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Creative větev používá Clarity Upscaler přes Replicate. Je výrazně blíž Magnific-style detail reconstruction než Gemini.")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                SectionLabel("Zvětšení")
                CapsuleSegmentedPicker(
                    title: "Upscale factor",
                    options: UpscaleScale.allCases.map { ($0, $0.title) },
                    selection: $scale
                )
                Text(scale == .x4 ? "2K výstup s větším důrazem na detail." : "1K výstup pro rychlejší a věrné zvětšení.")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !images.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    SectionLabel("Stav úlohy")
                    statusRow("Vstupů", value: "\(images.count)")
                    statusRow("Čeká", value: "\(pendingCount)")
                    statusRow("Běží", value: "\(runningCount)")
                    statusRow("Retry", value: "\(retryingCount)")
                    statusRow("Hotovo", value: "\(doneCount)")
                    statusRow("Souběh", value: "\(activeConcurrency)")
                    Text(concurrencyReason)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if batchTotal > 0 {
                        Text("\(batchCurrent)/\(batchTotal) • \(activeFileName)")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        } results: {
            if outputs.isEmpty {
                LibraryEmptyState(
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    title: "Zatím žádné upscale výstupy",
                    subtitle: "Nahraj obrázky vlevo a spusť Faithful nebo Creative upscale."
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: DS.Space.m, alignment: .top)],
                        alignment: .leading,
                        spacing: DS.Space.m
                    ) {
                        ForEach(sortedOutputs) { output in
                            upscaleCard(output)
                        }
                    }
                    .padding(DS.Space.l)
                }
            }
        } onRun: {
            run()
        }
    }

    private func run() {
        let engine = ToolEngine(env: env)
        let inputsToProcess = images.filter { url in
            outputs.first(where: { $0.id == outputID(for: url) && $0.status == .done }) == nil
        }

        guard !inputsToProcess.isEmpty else {
            error = "Všechny vstupy už mají hotový výstup pro aktuální režim a model."
            return
        }

        let prepared: [(url: URL, input: InputImage)] = inputsToProcess.compactMap { url in
            guard let input = engine.loadInput(url) else { return nil }
            return (url, input)
        }
        guard !prepared.isEmpty else {
            error = "Nepodařilo se načíst vstupní obrázky."
            return
        }

        let decision = concurrencyDecision(for: prepared.map(\.url))
        activeConcurrency = decision.concurrency
        concurrencyReason = decision.reason
        batchCurrent = 0
        batchTotal = prepared.count
        activeFileName = prepared.first?.url.lastPathComponent ?? ""
        error = nil
        busy = true

        let newOutputs = prepared.map { item in
            UpscalerOutput(
                id: outputID(for: item.url),
                inputURL: item.url,
                inputName: item.url.lastPathComponent,
                branch: branch,
                mode: branch == .faithful ? mode : nil,
                faithfulModel: branch == .faithful ? model : nil,
                creativePreset: branch == .creative ? creativePreset : nil,
                scale: scale,
                providerKind: branch == .creative ? .replicate : .gemini,
                createdAt: Date(),
                status: .pending,
                detailText: detailLabel(branch: branch, mode: mode, model: model, preset: creativePreset),
                image: nil
            )
        }
        outputs.removeAll { existing in
            newOutputs.contains(where: { $0.id == existing.id })
        }
        outputs.append(contentsOf: newOutputs)

        let branchSnapshot = branch
        let modeSnapshot = mode
        let modelSnapshot = model
        let creativePresetSnapshot = creativePreset
        let scaleSnapshot = scale

        Task {
            defer {
                Task { @MainActor in
                    busy = false
                    batchCurrent = 0
                    batchTotal = 0
                    activeFileName = ""
                }
            }

            var handled = 0
            for chunkStart in stride(from: 0, to: prepared.count, by: decision.concurrency) {
                let chunk = Array(prepared[chunkStart..<min(chunkStart + decision.concurrency, prepared.count)])
                await withTaskGroup(of: Void.self) { group in
                    for item in chunk {
                        group.addTask {
                            await runSingleUpscale(
                                item,
                                engine: engine,
                                branch: branchSnapshot,
                                mode: modeSnapshot,
                                model: modelSnapshot,
                                creativePreset: creativePresetSnapshot,
                                scale: scaleSnapshot
                            )
                        }
                    }
                }
                handled += chunk.count
                await MainActor.run {
                    batchCurrent = handled
                }
            }
        }
    }

    @MainActor
    private func runSingleUpscale(
        _ item: (url: URL, input: InputImage),
        engine: ToolEngine,
        branch: UpscaleBranch,
        mode: UpscaleMode,
        model: UpscaleModelChoice,
        creativePreset: CreativeUpscalePreset,
        scale: UpscaleScale
    ) async {
        let id = outputID(
            for: item.url,
            branch: branch,
            mode: branch == .faithful ? mode : nil,
            model: branch == .faithful ? model : nil,
            preset: branch == .creative ? creativePreset : nil,
            scale: scale
        )
        let maxAttempts = 3
        activeFileName = item.url.lastPathComponent

        for attempt in 1...maxAttempts {
            updateOutput(id: id) { output in
                output.status = attempt == 1 ? .running : .retrying
                output.attempt = attempt
                output.error = nil
                let label = detailLabel(branch: branch, mode: mode, model: model, preset: creativePreset)
                output.detailText = attempt == 1
                    ? "\(label) • odesílám…"
                    : "\(label) • opakuji \(attempt)/\(maxAttempts)…"
            }

            do {
                let generated = try await generatedOutput(
                    engine: engine,
                    input: item.input,
                    branch: branch,
                    mode: mode,
                    model: model,
                    creativePreset: creativePreset,
                    scale: scale
                )
                let stored = env.library.store(
                    imageData: generated.imageData,
                    prompt: branch == .faithful ? mode.title : creativePreset.title,
                    modelID: generated.modelID,
                    runID: nil,
                    variantLabel: "\(detailLabel(branch: branch, mode: mode, model: model, preset: creativePreset)) • \(scale.title)",
                    providerName: branch == .creative ? AIProviderKind.replicate.rawValue : AIProviderKind.gemini.rawValue,
                    aspectRatio: "Original",
                    resolution: branch == .creative ? "Creative \(scale.title)" : scale.geminiResolution
                )
                let dimensions = ToolEngine.pixelSize(for: generated.imageData)

                updateOutput(id: id) { output in
                    output.status = .done
                    output.image = stored
                    output.resultWidth = dimensions?.width
                    output.resultHeight = dimensions?.height
                    output.detailText = "\(detailLabel(branch: branch, mode: mode, model: model, preset: creativePreset)) • \(dimensionsText(for: dimensions))"
                    output.error = nil
                    output.attempt = attempt
                }
                return
            } catch {
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .milliseconds(500))
                    continue
                }
                updateOutput(id: id) { output in
                    output.status = .error
                    output.error = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                    output.detailText = item.url.lastPathComponent
                    output.attempt = attempt
                }
            }
        }
    }

    private func updateOutput(id: String, mutate: (inout UpscalerOutput) -> Void) {
        guard let index = outputs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&outputs[index])
    }

    private func outputID(
        for url: URL,
        branch: UpscaleBranch? = nil,
        mode: UpscaleMode? = nil,
        model: UpscaleModelChoice? = nil,
        preset: CreativeUpscalePreset? = nil,
        scale: UpscaleScale? = nil
    ) -> String {
        let branch = branch ?? self.branch
        let mode = mode ?? self.mode
        let model = model ?? self.model
        let preset = preset ?? self.creativePreset
        let scale = scale ?? self.scale
        switch branch {
        case .faithful:
            return "\(url.path)-faithful-\(mode.rawValue)-\(model.rawValue)-\(scale.rawValue)"
        case .creative:
            return "\(url.path)-creative-\(preset.rawValue)-\(scale.rawValue)"
        }
    }

    private var sortedOutputs: [UpscalerOutput] {
        outputs.sorted { $0.createdAt > $1.createdAt }
    }

    private var pendingCount: Int {
        outputs.filter { matchesCurrentConfiguration($0) && $0.status == .pending }.count
    }

    private var runningCount: Int {
        outputs.filter { matchesCurrentConfiguration($0) && $0.status == .running }.count
    }

    private var retryingCount: Int {
        outputs.filter { matchesCurrentConfiguration($0) && $0.status == .retrying }.count
    }

    private var doneCount: Int {
        outputs.filter { matchesCurrentConfiguration($0) && $0.status == .done }.count
    }

    @ViewBuilder
    private func upscaleCard(_ output: UpscalerOutput) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(DS.Palette.fieldBackground)

                switch output.status {
                case .done:
                    if let nsImage = output.image?.nsImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .error:
                    VStack(spacing: DS.Space.s) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.red)
                        Text(output.error ?? "Selhalo")
                            .font(.dsCaption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Space.m)
                    }
                case .pending, .running, .retrying:
                    VStack(spacing: DS.Space.s) {
                        ProgressView()
                            .controlSize(.small)
                        Text(output.status == .retrying ? "Opakuji…" : "Generuji…")
                            .font(.dsSmallSemibold)
                            .foregroundStyle(.secondary)
                        Capsule()
                            .fill(Color.accentColor.opacity(0.18))
                            .frame(height: 2)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: output.status == .pending ? 24 : 72, height: 2)
                            }
                            .padding(.horizontal, 36)
                    }
                }
            }
            .frame(minHeight: 210)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(output.inputName)
                    .font(.dsSmallSemibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(cardLabel(for: output))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(output.detailText)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            .padding(.top, DS.Space.s)
        }
    }

    private func statusRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.dsCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.dsValue)
                .foregroundStyle(.primary)
        }
    }

    private func dimensionsText(for size: (width: Int, height: Int)?) -> String {
        guard let size else { return branch == .creative ? scale.title : scale.geminiResolution }
        return "\(size.width)×\(size.height)"
    }

    private var currentRunTitle: String {
        switch branch {
        case .faithful:
            mode.title
        case .creative:
            "Creative \(creativePreset.title)"
        }
    }

    private func cardLabel(for output: UpscalerOutput) -> String {
        switch output.branch {
        case .faithful:
            return "\(output.mode?.title ?? "Faithful") • \(output.faithfulModel?.title ?? "Gemini")"
        case .creative:
            return "Creative • \(output.creativePreset?.title ?? "Clarity")"
        }
    }

    private func detailLabel(
        branch: UpscaleBranch,
        mode: UpscaleMode,
        model: UpscaleModelChoice,
        preset: CreativeUpscalePreset
    ) -> String {
        switch branch {
        case .faithful:
            "\(mode.title) • \(model.title)"
        case .creative:
            "Creative • \(preset.title)"
        }
    }

    private func matchesCurrentConfiguration(_ output: UpscalerOutput) -> Bool {
        guard output.branch == branch && output.scale == scale else { return false }
        switch branch {
        case .faithful:
            return output.mode == mode && output.faithfulModel == model
        case .creative:
            return output.creativePreset == creativePreset
        }
    }

    private func concurrencyDecision(for urls: [URL]) -> (concurrency: Int, reason: String) {
        guard branch == .faithful else {
            return (1, "creative upscale běží bezpečně po jednom")
        }
        return ToolEngine.decideAdaptiveConcurrency(for: urls)
    }

    private func generatedOutput(
        engine: ToolEngine,
        input: InputImage,
        branch: UpscaleBranch,
        mode: UpscaleMode,
        model: UpscaleModelChoice,
        creativePreset: CreativeUpscalePreset,
        scale: UpscaleScale
    ) async throws -> GenerationOutput {
        switch branch {
        case .faithful:
            return try await engine.generateOutput(
                inputs: [input],
                prompt: mode.prompt,
                providerKind: .gemini,
                modelID: model.modelID,
                resolution: scale.geminiResolution
            )
        case .creative:
            return try await engine.generateOutput(
                inputs: [input],
                prompt: creativePreset.prompt,
                providerKind: .replicate,
                modelID: ReplicateProvider.clarityModelID,
                providerOptions: [
                    "scale_factor": .double(Double(scale.rawValue)),
                    "creativity": .double(creativePreset.creativity),
                    "resemblance": .double(creativePreset.resemblance),
                    "dynamic": .double(creativePreset.dynamic),
                    "sharpen": .double(creativePreset.sharpen),
                    "handfix": .string("disabled"),
                    "pattern": .bool(false),
                    "output_format": .string("png"),
                    "downscaling": .bool(false),
                ]
            )
        }
    }
}

private struct ToolJobCard: View {
    let status: ToolJobStatus
    let progress: Double
    let image: LibraryImage?
    let title: String
    let detail: String
    let error: String?
    let workingLabel: String
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(DS.Palette.fieldBackground)

                switch status {
                case .done:
                    if let nsImage = image?.nsImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .error:
                    VStack(spacing: DS.Space.s) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.red)
                        Text(error ?? "Úloha selhala")
                            .font(.dsCaption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .padding(.horizontal, DS.Space.m)
                    }
                case .pending, .running, .retrying:
                    VStack(spacing: DS.Space.m) {
                        ProgressView().controlSize(.small)
                        Text(status == .retrying ? "Opakuji…" : workingLabel)
                            .font(.dsSmallSemibold)
                            .foregroundStyle(.secondary)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: proxy.size.width * progress)
                            }
                        }
                        .frame(width: 130, height: 3)
                        Text("\(Int(progress * 100)) %")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(minHeight: 230)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.dsSmallSemibold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(detail)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Space.s)
                if image != nil {
                    Button(action: onDownload) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.plain)
                    .help("Stáhnout")
                }
            }
        }
        .contextMenu {
            if image != nil {
                Button("Stáhnout…", action: onDownload)
            }
            Button("Odebrat kartu", role: .destructive, action: onDelete)
        }
    }
}

private func toolAspectRatio(for data: Data) -> String {
    guard let size = ToolEngine.pixelSize(for: data) else { return "Original" }
    let divisor = greatestCommonDivisor(size.width, size.height)
    return "\(size.width / divisor):\(size.height / divisor)"
}

private func greatestCommonDivisor(_ first: Int, _ second: Int) -> Int {
    var a = abs(first)
    var b = abs(second)
    while b != 0 {
        (a, b) = (b, a % b)
    }
    return max(1, a)
}

private func toolDownload(_ image: LibraryImage, prefix: String) {
    guard let data = image.imageData else { return }
    ImageExport.save(data, suggestedName: "\(prefix)-\(Int(image.createdAt.timeIntervalSince1970)).png")
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
