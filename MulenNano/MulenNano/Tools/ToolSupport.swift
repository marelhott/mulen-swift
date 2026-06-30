//
//  ToolSupport.swift
//  MulenNano
//
//  Sdílená infrastruktura nástrojů (Upscaler, Face Swap, Reframe, Batch):
//  engine pro úpravy přes Gemini + jednotná skořápka pohledu.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

// MARK: - Engine
struct ToolEngine {
    let env: AppEnvironment
    static let defaultModel = "gemini-3-pro-image"

    /// Úprava obrázku přes Gemini → uloží do knihovny.
    func edit(inputs: [InputImage], prompt: String, label: String, variant: String? = nil) async throws {
        let out = try await generateOutput(
            inputs: inputs,
            prompt: prompt,
            providerKind: .gemini,
            modelID: Self.defaultModel,
            resolution: nil
        )
        env.library.store(
            imageData: out.imageData,
            prompt: label,
            modelID: out.modelID,
            runID: nil,
            variantLabel: variant,
            providerName: AIProviderKind.gemini.rawValue
        )
    }

    func generateOutput(
        inputs: [InputImage],
        prompt: String,
        providerKind: AIProviderKind = .gemini,
        modelID: String = "gemini-3-pro-image",
        resolution: String? = nil,
        providerOptions: [String: ProviderOptionValue] = [:]
    ) async throws -> GenerationOutput {
        guard let provider = env.providers.provider(for: providerKind),
              let key = env.providers.apiKey(for: providerKind), !key.isEmpty else {
            throw ProviderError.api("Chybí \(providerKind.rawValue) API klíč. Zadej ho v Nastavení (⌘,).")
        }
        let req = GenerationRequest(
            prompt: prompt,
            inputImages: inputs,
            modelID: modelID,
            aspectRatio: "Original",
            resolution: resolution,
            grounding: false,
            allowModelFallback: false,
            providerOptions: providerOptions
        )
        return try await provider.generate(req, apiKey: key)
    }

    func loadInput(_ url: URL) -> InputImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let mime = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.preferredMIMEType ?? "image/png"
        return InputImage(data: data, mimeType: mime)
    }

    static func decideAdaptiveConcurrency(for urls: [URL]) -> (concurrency: Int, reason: String) {
        guard !urls.isEmpty else { return (1, "bez vstupu") }
        let sizes = urls.compactMap { try? Data(contentsOf: $0).count }.map { Double($0) / 1_048_576.0 }
        let average = sizes.isEmpty ? 0 : sizes.reduce(0, +) / Double(sizes.count)
        let maxSize = sizes.max() ?? 0
        if maxSize > 4.5 || average > 3 {
            return (1, "těžké podklady pro upscale")
        }
        return (min(2, urls.count), "bezpečný upscale souběh")
    }

    static func pixelSize(for data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue else {
            return nil
        }
        return (width, height)
    }
}

// MARK: - Kompozit pro Face Swap (cíl + zdroj v insetu vpravo nahoře)
enum ToolImage {
    static func composite(targetData: Data, sourceData: Data) -> InputImage? {
        guard let target = NSImage(data: targetData), let source = NSImage(data: sourceData) else { return nil }
        let targetPixels = pixelSize(of: target)
        let targetScale = min(1, 2048 / max(targetPixels.width, targetPixels.height))
        let size = NSSize(
            width: max(1, (targetPixels.width * targetScale).rounded()),
            height: max(1, (targetPixels.height * targetScale).rounded())
        )
        let result = NSImage(size: size)
        result.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        drawAspectFill(target, in: NSRect(origin: .zero, size: size))

        let insetW = size.width * 0.24
        let insetH = size.height * 0.24
        let margin = min(size.width, size.height) * 0.025
        let rect = NSRect(x: size.width - insetW - margin,
                          y: size.height - insetH - margin,
                          width: insetW, height: insetH)
        NSColor.black.withAlphaComponent(0.78).setFill()
        rect.insetBy(dx: -6, dy: -6).fill()
        drawAspectFit(source, in: rect)
        result.unlockFocus()

        guard let tiff = result.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return InputImage(data: png, mimeType: "image/png")
    }

    private static func pixelSize(of image: NSImage) -> NSSize {
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return NSSize(width: max(bitmap.pixelsWide, 1), height: max(bitmap.pixelsHigh, 1))
        }
        return image.size
    }

    private static func drawAspectFill(_ image: NSImage, in rect: NSRect) {
        let source = pixelSize(of: image)
        let scale = max(rect.width / source.width, rect.height / source.height)
        let drawSize = NSSize(width: source.width * scale, height: source.height * scale)
        let drawRect = NSRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private static func drawAspectFit(_ image: NSImage, in rect: NSRect) {
        let source = pixelSize(of: image)
        let scale = min(rect.width / source.width, rect.height / source.height)
        let drawSize = NSSize(width: source.width * scale, height: source.height * scale)
        let drawRect = NSRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

// MARK: - Skořápka nástroje
struct ToolScaffold<Controls: View>: View {
    @Environment(AppEnvironment.self) private var env
    let runLabel: String
    let canRun: Bool
    let busy: Bool
    var error: String?
    @ViewBuilder var controls: () -> Controls
    let onRun: () -> Void

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    toolActions
                    Hairline()
                    controls()
                }
                .padding(DS.Space.l)
            }
            .frame(minWidth: 260, idealWidth: 280, maxWidth: 340)
            .background(.clear)

            results
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var results: some View {
        if env.library.images.isEmpty && !busy {
            LibraryEmptyState(systemImage: "photo", title: "Zatím žádné výsledky")
                .background(.clear)
        } else {
            LibraryGrid(images: env.library.images)
                .background(.clear)
        }
    }

    private var toolActions: some View {
        VStack(spacing: DS.Space.s) {
            Button(action: onRun) {
                HStack {
                    if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "Pracuji…" : runLabel)
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!canRun || busy)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.dsCaption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ToolSplitScaffold<Controls: View, Results: View>: View {
    let runLabel: String
    let canRun: Bool
    let busy: Bool
    var error: String?
    @ViewBuilder var controls: () -> Controls
    @ViewBuilder var results: () -> Results
    let onRun: () -> Void

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    toolActions
                    Hairline()
                    controls()
                }
                .padding(DS.Space.l)
            }
            .frame(minWidth: 260, idealWidth: 280, maxWidth: 340)
            .background(.clear)

            results()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var toolActions: some View {
        VStack(spacing: DS.Space.s) {
            Button(action: onRun) {
                HStack {
                    if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "Pracuji…" : runLabel)
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!canRun || busy)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.dsCaption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
