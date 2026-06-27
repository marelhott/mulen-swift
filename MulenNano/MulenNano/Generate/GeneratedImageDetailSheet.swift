//
//  GeneratedImageDetailSheet.swift
//  MulenNano
//
//  Detail výsledku generování s metadaty a prompt iterací nad vybraným obrázkem.
//

import SwiftUI

struct GeneratedImageDetailSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let imageID: UUID
    let busy: Bool
    let errorMessage: String?
    let onRegenerate: (String) -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onAssignCollection: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    @State private var editPrompt: String
    @State private var zoom: Double = 1
    @State private var committedZoom: Double = 1

    init(
        image: LibraryImage,
        busy: Bool,
        errorMessage: String?,
        onRegenerate: @escaping (String) -> Void,
        onDownload: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onAssignCollection: @escaping () -> Void,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void
    ) {
        self.imageID = image.id
        self.busy = busy
        self.errorMessage = errorMessage
        self.onRegenerate = onRegenerate
        self.onDownload = onDownload
        self.onDelete = onDelete
        self.onAssignCollection = onAssignCollection
        self.onUndo = onUndo
        self.onRedo = onRedo
        _editPrompt = State(initialValue: image.prompt)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            HSplitView {
                preview
                    .frame(minWidth: 420, idealWidth: 560)
                inspector
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .onChange(of: image?.prompt) { _, newValue in
            guard let newValue, !busy else { return }
            editPrompt = newValue
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: DS.Space.s) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                HStack(spacing: DS.Space.s) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Slider(value: $zoom, in: 0.6...4, step: 0.05)
                        .frame(width: 120)
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, DS.Space.s)
                .background(.regularMaterial, in: Capsule())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(image?.updatedAt.formatted(date: .long, time: .standard) ?? "Detail výsledku")
                    .font(.title3.weight(.semibold))
                Text(imageSummary)
                    .font(.dsLabel)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: DS.Space.s) {
                circleAction("info.circle")
                circleAction("square.and.arrow.up", action: onDownload)
                circleAction("heart")
                circleAction("doc.on.doc")
                circleAction("sparkles", action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoom = 1
                        committedZoom = 1
                    }
                })
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .background(.regularMaterial, in: Capsule())

            Button("Upravit") { }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(DS.Space.l)
        .background(.ultraThinMaterial)
    }

    private var preview: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.92), Color(nsColor: .windowBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let nsImage = image?.nsImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoom)
                        .blur(radius: busy ? 14 : 0)
                        .animation(.easeInOut(duration: 0.25), value: busy)
                        .padding(DS.Space.xxl)
                        .id(image?.updatedAt)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    zoom = max(0.6, min(4, committedZoom * value.magnification))
                                }
                                .onEnded { _ in
                                    committedZoom = zoom
                                }
                        )
                }
            } else {
                VStack(spacing: DS.Space.m) {
                    Image(systemName: "photo")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundStyle(.quaternary)
                    Text("Náhled není dostupný")
                        .font(.dsEmptyTitle)
                        .foregroundStyle(.secondary)
                    Text("Soubor obrázku se nepodařilo načíst.")
                        .font(.dsCaption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                metadata
                Hairline()
                promptEditor
                Hairline()
                actions
            }
            .padding(DS.Space.l)
        }
        .background(.background)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Metadata")
            metaRow("Provider", image?.providerName ?? "—")
            metaRow("Model", image?.modelID ?? "—")
            metaRow("Poměr stran", image?.aspectRatio ?? "—")
            metaRow("Rozlišení", image?.resolution ?? "—")
            if let label = image?.variantLabel, !label.isEmpty {
                metaRow("Varianta", label)
            }
            metaRow("Vytvořeno", image?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "—")
        }
    }

    private func metaRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.dsCaption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.dsLabel)
                .textSelection(.enabled)
        }
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Upravit prompt")
            TextEditor(text: $editPrompt)
                .font(.dsLabel)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(DS.Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(DS.Palette.fieldBackground)
                )

            if let errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.dsCaption)
                    .foregroundStyle(.red)
            }

            Button {
                onRegenerate(editPrompt)
            } label: {
                HStack {
                    if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "Upravuji…" : "Upravit obrázek")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(editPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)

            Button("Undo", action: onUndo)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled((image?.revisions.isEmpty ?? true) || busy)

            Button("Redo", action: onRedo)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled((image?.undoneRevisions.isEmpty ?? true) || busy)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Akce")

            Button("Stáhnout…", action: onDownload)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Přidat do kolekce…", action: onAssignCollection)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Smazat", role: .destructive, action: onDelete)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderless)
    }

    private var image: LibraryImage? {
        env.library.images.first(where: { $0.id == imageID })
    }

    private var imageSummary: String {
        guard let image else { return "" }
        let width = Int(image.nsImage?.size.width ?? 0)
        let height = Int(image.nsImage?.size.height ?? 0)
        if width > 0, height > 0 {
            return "\(width) × \(height)"
        }
        return image.aspectRatio ?? ""
    }

    private func circleAction(_ systemName: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .regular))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }
}
