//
//  LibraryView.swift
//  MulenNano
//
//  Hlavní knihovna „Vše" — mřížka všech vygenerovaných obrázků.
//

import SwiftUI

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var detailImage: LibraryImage?
    @State private var detailEditImageID: UUID?
    @State private var detailBusy: Bool = false
    @State private var detailError: String?

    private let inputGrid = [
        GridItem(.adaptive(minimum: 84, maximum: 112), spacing: DS.Space.s, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                librarySectionTitle("Generované obrázky", count: env.library.images.count)

                if env.library.images.isEmpty {
                    sectionEmptyState("Zatím žádné generované obrázky.")
                } else {
                    LibraryGrid(images: env.library.images, embedded: true) { open($0) }
                }

                Hairline()

                librarySectionTitle("Vstupní obrázky", count: env.library.inputImages.count)

                if env.library.inputImages.isEmpty {
                    sectionEmptyState("Vložené obrázky se uloží sem pro další použití.")
                } else {
                    LazyVGrid(columns: inputGrid, alignment: .leading, spacing: DS.Space.s) {
                        ForEach(env.library.inputImages) { inputTile($0) }
                    }
                }
            }
            .padding(DS.Space.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
        .overlay {
            if let detailImage {
                detailOverlay(detailImage)
            }
        }
    }

    private func open(_ image: LibraryImage) {
        withAnimation(.easeOut(duration: 0.18)) {
            detailImage = image
            detailError = nil
        }
    }

    private func closeDetail() {
        withAnimation(.easeOut(duration: 0.16)) {
            detailImage = nil
            detailError = nil
        }
    }

    @ViewBuilder
    private func detailOverlay(_ image: LibraryImage) -> some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { closeDetail() }

            GeneratedImageDetailSheet(
                image: image,
                busy: detailEditImageID == image.id && detailBusy,
                errorMessage: detailError,
                onRegenerate: { regenerate(image, prompt: $0) },
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

    // MARK: Akce

    private func download(_ image: LibraryImage) {
        guard let data = image.imageData else { return }
        ImageExport.save(data, suggestedName: "mulen-\(Int(image.createdAt.timeIntervalSince1970)).png")
    }

    /// Self-contained AI edit přes aktivního providera (ekvivalent iterate z GenerateView).
    private func regenerate(_ image: LibraryImage, prompt: String) {
        detailError = nil
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let kind = AIProviderKind(rawValue: image.providerName ?? "")
            ?? AIProviderKind.allCases.first { env.providers.hasKey(for: $0) }
        guard let kind else {
            detailError = "Chybí API klíč. Zadej ho v Nastavení (⌘,)."
            return
        }
        guard env.providers.isImplemented(kind),
              let provider = env.providers.provider(for: kind),
              let apiKey = env.providers.apiKey(for: kind), !apiKey.isEmpty else {
            detailError = "Chybí API klíč pro \(kind.rawValue). Zadej ho v Nastavení (⌘,)."
            return
        }
        guard let data = try? Data(contentsOf: image.fileURL) else {
            detailError = "Nepodařilo se načíst zdrojový obrázek."
            return
        }

        let req = GenerationRequest(
            prompt: trimmed,
            inputImages: [InputImage(data: data, mimeType: "image/png")],
            modelID: image.modelID,
            aspectRatio: image.aspectRatio,
            resolution: image.resolution
        )

        detailBusy = true
        detailEditImageID = image.id

        Task {
            defer {
                detailBusy = false
                detailEditImageID = nil
            }
            do {
                let output = try await provider.generate(req, apiKey: apiKey)
                env.library.replaceImage(
                    image.id,
                    imageData: output.imageData,
                    prompt: trimmed,
                    modelID: output.modelID,
                    providerName: kind.rawValue,
                    aspectRatio: image.aspectRatio,
                    resolution: image.resolution
                )
            } catch {
                detailError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func librarySectionTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: DS.Space.s) {
            SectionLabel(title)
            Text("\(count)")
                .font(.dsCaption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    private func sectionEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.dsCaption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
    }

    private func inputTile(_ input: SavedInputImage) -> some View {
        Group {
            if let nsImage = input.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
            }
        }
        .contextMenu {
            Button("Odstranit z uložených vstupů", role: .destructive) {
                env.library.removeInputImage(input.id)
            }
        }
    }
}
