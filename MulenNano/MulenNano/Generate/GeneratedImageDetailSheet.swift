//
//  GeneratedImageDetailSheet.swift
//  MulenNano
//
//  Detail výsledku generování s metadaty a prompt iterací nad vybraným obrázkem.
//

import SwiftUI
import AppKit

enum DetailInspectorTab: Hashable {
    case prompt, edit
}

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

    // Úpravy Photos-style
    @State private var inspectorTab: DetailInspectorTab = .prompt
    @State private var editingSession: PhotoEditingSession?

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
        .onChange(of: image?.updatedAt) { _, _ in
            // Obrázek se změnil (regenerace) → zrušit editační session.
            editingSession = nil
            inspectorTab = .prompt
        }
        .onChange(of: inspectorTab) { _, tab in
            if tab == .edit { ensureEditingSession() }
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
            if let nsImage = canvasImage {
                ZoomableImageScrollView(
                    image: nsImage,
                    imageID: imageID,
                    zoom: $zoom,
                    busy: busy
                )
                .id(imageID)
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
        VStack(spacing: 0) {
            inspectorTabs
            Hairline()
            Group {
                switch inspectorTab {
                case .prompt:
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Space.l) {
                            metadata
                            Hairline()
                            promptEditor
                        }
                        .padding(DS.Space.l)
                    }
                    .background(.clear)
                case .edit:
                    if let session = editingSession {
                        PhotoEditorPanel(
                            session: session,
                            onApply: { applyEdits(session) },
                            onRevert: { session.resetAll() }
                        )
                    } else {
                        editLoadingPlaceholder
                    }
                }
            }
        }
        .background(.clear)
    }

    private var inspectorTabs: some View {
        HStack(spacing: DS.Space.xs) {
            Picker("", selection: $inspectorTab) {
                Text("Prompt").tag(DetailInspectorTab.prompt)
                Text("Upravit").tag(DetailInspectorTab.edit)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.s)
    }

    private var editLoadingPlaceholder: some View {
        VStack(spacing: DS.Space.m) {
            Spacer()
            ProgressView()
            Text("Připravuji úpravy…")
                .font(.dsCaption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            ensureEditingSession()
        }
    }

    private func ensureEditingSession() {
        guard editingSession == nil, let img = image?.nsImage else { return }
        editingSession = PhotoEditingSession(source: img)
    }

    private func applyEdits(_ session: PhotoEditingSession) {
        guard let id = image?.id,
              let data = session.renderFullRes() ?? image?.imageData else { return }
        env.library.replaceImage(
            id,
            imageData: data,
            prompt: image?.prompt ?? "",
            modelID: image?.modelID ?? "",
            providerName: image?.providerName,
            aspectRatio: image?.aspectRatio,
            resolution: image?.resolution
        )
        editingSession = nil
        inspectorTab = .prompt
    }

    private var canvasImage: NSImage? {
        if inspectorTab == .edit, let session = editingSession {
            return session.previewImage ?? session.sourceImage ?? image?.nsImage
        }
        return image?.nsImage
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
    let imageID: UUID
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
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true

        container.addSubview(imageView)
        scrollView.documentView = container

        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = container
        context.coordinator.imageView = imageView

        // Spolehlivé přepočítání když layout získá reálnou velikost.
        let coordinator = context.coordinator
        scrollView.onLayout = { [weak coordinator] in
            coordinator?.relayout()
        }
        let clip = scrollView.contentView
        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clip,
            queue: .main
        ) { [weak coordinator] _ in
            coordinator?.relayout()
        }

        context.coordinator.update(image: image, imageID: imageID, zoom: zoom, busy: busy)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(image: image, imageID: imageID, zoom: zoom, busy: busy)
    }

    final class Coordinator: NSObject {
        @Binding private var zoom: Double
        weak var scrollView: CenteringScrollView?
        weak var containerView: NSView?
        weak var imageView: NSImageView?
        private var lastImageID: UUID?

        private var currentImage: NSImage?
        private var currentImageID: UUID?
        private var currentZoom: Double = 1
        private var currentBusy: Bool = false
        private var retryScheduled = false

        init(zoom: Binding<Double>) {
            _zoom = zoom
        }

        func update(image: NSImage, imageID: UUID, zoom: Double, busy: Bool) {
            currentImage = image
            currentImageID = imageID
            currentZoom = zoom
            currentBusy = busy
            relayout()
        }

        /// Přepočítá velikost obrázku podle aktuálního viewportu.
        /// Bezpečné volat opakovaně; při nulovém viewportu naplánuje retry.
        func relayout() {
            guard let scrollView, let containerView, let imageView,
                  let image = currentImage else { return }
            let imageSize = image.pixelSize
            let viewport = scrollView.contentView.bounds.size

            // Viewport zatím nemá reálnou velikost → počkáme na layout.
            guard viewport.width > 1 || viewport.height > 1 else {
                scheduleRetry()
                return
            }

            let insets = scrollView.contentInsets
            let availableSize = CGSize(
                width: max(1, viewport.width - insets.left - insets.right),
                height: max(1, viewport.height - insets.top - insets.bottom)
            )
            let fitted = aspectFitSize(imageSize, inside: availableSize)
            let displaySize = CGSize(
                width: max(1, fitted.width * currentZoom),
                height: max(1, fitted.height * currentZoom)
            )

            if imageView.image !== image {
                imageView.image = image
            }
            if let layer = imageView.layer {
                layer.masksToBounds = true
                layer.opacity = currentBusy ? 0.35 : 1
            }

            let shouldRecenter = lastImageID != currentImageID
            lastImageID = currentImageID

            // Zda se velikost mění — předejdeme smyčce s tile().
            if containerView.frame.size != displaySize {
                imageView.frame = NSRect(origin: .zero, size: displaySize)
                containerView.frame = NSRect(origin: .zero, size: displaySize)
                scrollView.minMagnification = 0.5
                scrollView.maxMagnification = 8
            }

            DispatchQueue.main.async {
                scrollView.reflectScrolledClipView(scrollView.contentView)
                scrollView.centerDocumentIfNeeded()
                if shouldRecenter {
                    scrollView.contentView.scroll(to: .zero)
                    scrollView.centerDocumentIfNeeded()
                }
            }
        }

        private func scheduleRetry() {
            guard !retryScheduled else { return }
            retryScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.retryScheduled = false
                self?.relayout()
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
    /// Voláno při změně layoutu → coordinator přepočítá velikost obrázku.
    var onLayout: (() -> Void)?

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
        onLayout?()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onLayout?()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        onLayout?()
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
