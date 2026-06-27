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

// MARK: - Engine
struct ToolEngine {
    let env: AppEnvironment
    static let defaultModel = "gemini-3-pro-image-preview"

    /// Úprava obrázku přes Gemini → uloží do knihovny.
    func edit(inputs: [InputImage], prompt: String, label: String, variant: String? = nil) async throws {
        guard let provider = env.providers.provider(for: .gemini),
              let key = env.providers.apiKey(for: .gemini), !key.isEmpty else {
            throw ProviderError.api("Chybí Gemini API klíč. Zadej ho v Nastavení (⌘,).")
        }
        let req = GenerationRequest(prompt: prompt, inputImages: inputs,
                                    modelID: Self.defaultModel, aspectRatio: "Original", grounding: false)
        let out = try await provider.generate(req, apiKey: key)
        env.library.store(imageData: out.imageData, prompt: label, modelID: out.modelID, variantLabel: variant)
    }

    func loadInput(_ url: URL) -> InputImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let mime = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.preferredMIMEType ?? "image/png"
        return InputImage(data: data, mimeType: mime)
    }
}

// MARK: - Kompozit pro Face Swap (cíl + zdroj v insetu vpravo nahoře)
enum ToolImage {
    static func composite(targetData: Data, sourceData: Data) -> InputImage? {
        guard let target = NSImage(data: targetData), let source = NSImage(data: sourceData) else { return nil }
        let size = target.size
        let result = NSImage(size: size)
        result.lockFocus()
        target.draw(in: NSRect(origin: .zero, size: size))
        // inset ~30 % šířky vpravo nahoře
        let insetW = size.width * 0.3
        let insetH = insetW * (source.size.height / max(source.size.width, 1))
        let margin = size.width * 0.02
        let rect = NSRect(x: size.width - insetW - margin,
                          y: size.height - insetH - margin,
                          width: insetW, height: insetH)
        NSColor.black.setFill()
        rect.insetBy(dx: -2, dy: -2).fill()
        source.draw(in: rect)
        result.unlockFocus()

        guard let tiff = result.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return InputImage(data: png, mimeType: "image/png")
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
            VStack(alignment: .leading, spacing: DS.Space.l) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.l) {
                        controls()
                    }
                    .padding(DS.Space.l)
                }
                Spacer(minLength: 0)
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.dsCaption).foregroundStyle(.red)
                        .padding(.horizontal, DS.Space.l)
                }
                Button(action: onRun) {
                    HStack {
                        if busy { ProgressView().controlSize(.small) }
                        Text(busy ? "Pracuji…" : runLabel)
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(!canRun || busy)
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
}
