//
//  GeneratedImageDetailSheet.swift
//  MulenNano
//
//  Detail výsledku generování s metadaty a prompt iterací nad vybraným obrázkem.
//

import SwiftUI
import AppKit

struct GeneratedImageDetailSheet: View {
    @Environment(AppEnvironment.self) private var env

    let imageID: UUID
    let busy: Bool
    let errorMessage: String?
    let onRegenerate: (String) -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onClose: () -> Void

    @State private var editPrompt: String
    @State private var zoom: Double = 1

    init(
        image: LibraryImage,
        busy: Bool,
        errorMessage: String?,
        onRegenerate: @escaping (String) -> Void,
        onDownload: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.imageID = image.id
        self.busy = busy
        self.errorMessage = errorMessage
        self.onRegenerate = onRegenerate
        self.onDownload = onDownload
        self.onDelete = onDelete
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onClose = onClose
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
        .frame(minWidth: 700, minHeight: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: image?.prompt) { _, newValue in
            guard let newValue, !busy else { return }
            editPrompt = newValue
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: DS.Space.s) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                CompactScaleControl(
                    value: zoomBinding,
                    range: 0.5...8,
                    step: 0.25,
                    help: "Změnit přiblížení"
                )
                .accessibilityLabel("Přiblížení obrázku")
            }
            Spacer()
            VStack(spacing: 2) {
                Text(image?.updatedAt.formatted(date: .long, time: .standard) ?? "Detail výsledku")
                    .font(.dsStandardSemibold)
                Text(imageSummary)
                    .font(.dsLabel)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: DS.Space.m) {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 18, weight: .regular))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .help("Stáhnout")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .regular))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .help("Smazat")
            }
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
                ZoomableImageScrollView(
                    image: nsImage,
                    zoom: $zoom,
                    busy: busy
                )
                .id(image?.updatedAt)
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
            }
            .padding(DS.Space.l)
        }
        .background(.clear)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel("Metadata")
            metaRow("Provider", image?.providerName ?? "—")
            metaRow("Model", image?.modelID ?? "—")
            metaRow("Poměr stran", image?.aspectRatio ?? "—")
            metaRow("Profil výstupu", image?.resolution ?? "—")
            metaRow("Pixely souboru", imageSummary.isEmpty ? "—" : imageSummary)
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
            HStack(spacing: DS.Space.s) {
                SectionLabel("Upravit prompt")
                Spacer()
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled((image?.revisions.isEmpty ?? true) || busy)
                .help("Zpět")
                .accessibilityLabel("Zpět")

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled((image?.undoneRevisions.isEmpty ?? true) || busy)
                .help("Znovu")
                .accessibilityLabel("Znovu")
            }
            .buttonStyle(.plain)
            .font(.dsStandardMedium)
            .foregroundStyle(.secondary)

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
        }
    }

    private var image: LibraryImage? {
        env.library.images.first(where: { $0.id == imageID })
    }

    private var imageSummary: String {
        guard let size = image?.pixelSize else { return "" }
        let width = Int(size.width)
        let height = Int(size.height)
        if width > 0, height > 0 {
            return "\(width) × \(height)"
        }
        return ""
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { zoom },
            set: {
                zoom = $0
            }
        )
    }
}

private struct ZoomableImageScrollView: NSViewRepresentable {
    let image: NSImage
    @Binding var zoom: Double
    let busy: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(zoom: $zoom)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CenteringScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.allowsMagnification = false
        scrollView.contentInsets = NSEdgeInsets(
            top: DS.Space.xxl,
            left: DS.Space.xxl,
            bottom: DS.Space.xxl,
            right: DS.Space.xxl
        )

        let container = NSView(frame: .zero)
        let imageView = NSImageView(frame: .zero)
        imageView.image = image
        imageView.imageScaling = .scaleNone
        imageView.wantsLayer = true

        container.addSubview(imageView)
        scrollView.documentView = container

        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = container
        context.coordinator.imageView = imageView
        context.coordinator.update(image: image, zoom: zoom, busy: busy)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(image: image, zoom: zoom, busy: busy)
    }

    final class Coordinator: NSObject {
        @Binding private var zoom: Double
        weak var scrollView: CenteringScrollView?
        weak var containerView: NSView?
        weak var imageView: NSImageView?
        private var lastImageIdentifier: String?

        init(zoom: Binding<Double>) {
            _zoom = zoom
        }

        func update(image: NSImage, zoom: Double, busy: Bool) {
            guard let scrollView, let containerView, let imageView else { return }
            let imageKey = image.tiffRepresentation.map { String($0.hashValue) } ?? UUID().uuidString
            let imageSize = image.pixelSize
            let viewport = scrollView.contentView.bounds.size
            let insets = scrollView.contentInsets
            let availableSize = CGSize(
                width: max(1, viewport.width - insets.left - insets.right),
                height: max(1, viewport.height - insets.top - insets.bottom)
            )
            let fittedSize = aspectFitSize(imageSize, inside: availableSize)
            let displaySize = CGSize(
                width: max(1, fittedSize.width * zoom),
                height: max(1, fittedSize.height * zoom)
            )

            if imageView.image !== image {
                imageView.image = image
            }

            if let layer = imageView.layer {
                layer.cornerRadius = 0
                layer.masksToBounds = true
                layer.opacity = busy ? 0.35 : 1
            }

            imageView.frame = NSRect(origin: .zero, size: displaySize)
            containerView.frame = NSRect(origin: .zero, size: displaySize)
            scrollView.minMagnification = 0.5
            scrollView.maxMagnification = 8

            let shouldRecenter = lastImageIdentifier != imageKey
            lastImageIdentifier = imageKey

            DispatchQueue.main.async {
                scrollView.reflectScrolledClipView(scrollView.contentView)
                scrollView.centerDocumentIfNeeded()
                if shouldRecenter {
                    scrollView.contentView.scroll(to: .zero)
                    scrollView.centerDocumentIfNeeded()
                }
            }
        }

        private func aspectFitSize(_ imageSize: CGSize, inside availableSize: CGSize) -> CGSize {
            guard imageSize.width > 0, imageSize.height > 0 else { return availableSize }
            let scale = min(
                availableSize.width / imageSize.width,
                availableSize.height / imageSize.height
            )
            return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        }
    }
}

private final class CenteringScrollView: NSScrollView {
    func centerDocumentIfNeeded() {
        guard let documentView else { return }
        let clipBounds = contentView.bounds
        var frame = documentView.frame

        frame.origin.x = max(0, (clipBounds.width - frame.width) / 2)
        frame.origin.y = max(0, (clipBounds.height - frame.height) / 2)

        if documentView.frame.origin != frame.origin {
            documentView.frame = frame
        }
    }

    override func tile() {
        super.tile()
        centerDocumentIfNeeded()
    }
}

private extension NSImage {
    var pixelSize: CGSize {
        if let bitmap = representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        }
        return size
    }
}

private extension LibraryImage {
    var pixelSize: CGSize? {
        guard let image = nsImage else { return nil }
        return image.pixelSize
    }
}
