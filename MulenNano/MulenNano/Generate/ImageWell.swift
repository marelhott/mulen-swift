//
//  ImageWell.swift
//  MulenNano
//
//  Kompaktní nahrávací zóna pro obrázky. Klik = výběr ze souborů, drop = přetažení z Finderu.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageWell: View {
    @Environment(AppEnvironment.self) private var env
    let title: String
    @Binding var urls: [URL]
    var hint: String? = nil
    var maxCount: Int? = nil

    @State private var isTargeted = false
    @State private var galleryPanel = SavedInputGalleryPanelController()
    @State private var anchorFrame: CGRect = .zero

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.xs) {
                SectionLabel(title)
                Spacer()
                if !urls.isEmpty {
                    Text("\(urls.count)")
                        .font(.dsCaption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            Group {
                if urls.isEmpty {
                    emptyZone
                } else {
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(urls, id: \.self) { thumbnail($0) }
                        addTile
                    }
                }
            }
            .background {
                ImageWellAnchorReader { anchorFrame = $0 }
            }
            .onHover { hovering in
                galleryPanel.setAnchorHovered(
                    hovering,
                    anchorFrame: anchorFrame,
                    images: env.library.inputImages,
                    onSelect: append
                )
            }
            .onChange(of: anchorFrame) { _, newFrame in
                galleryPanel.refreshIfNeeded(
                    anchorFrame: newFrame,
                    images: env.library.inputImages,
                    onSelect: append
                )
            }
            .onChange(of: env.library.inputImages.map(\.id)) { _, _ in
                galleryPanel.refreshIfNeeded(
                    anchorFrame: anchorFrame,
                    images: env.library.inputImages,
                    onSelect: append
                )
            }

            if let hint {
                Text(hint)
                    .font(.dsCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { handleDrop($0) }
        .onDisappear { galleryPanel.close() }
    }

    private var emptyZone: some View {
        Button(action: openPanel) {
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.06) : DS.Palette.fieldBackground)
                .frame(height: 40)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .strokeBorder(isTargeted ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func thumbnail(_ url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(DS.Palette.fieldBackground)
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))

            Button {
                urls.removeAll { $0 == url }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(1)
        }
    }

    private var addTile: some View {
        Button(action: openPanel) {
            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                .fill(DS.Palette.fieldBackground)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
        }
        .buttonStyle(.plain)
    }

    private func openPanel() {
        galleryPanel.close()
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = maxCount != 1
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.title = "Vybrat vstupní obrázky"
        if panel.runModal() == .OK {
            panel.urls.compactMap(env.library.importInputImage).forEach(append)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url,
                      let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                      type.conforms(to: .image) else { return }
                DispatchQueue.main.async {
                    guard let imported = env.library.importInputImage(from: url) else { return }
                    append(imported)
                }
            }
        }
        return true
    }

    private func append(_ url: URL) {
        guard !urls.contains(url) else { return }
        if let maxCount, maxCount > 0, urls.count >= maxCount {
            urls.removeFirst(urls.count - maxCount + 1)
        }
        urls.append(url)
    }
}

private struct SavedInputGalleryPanelContent: View {
    let panelSize: CGSize
    let images: [SavedInputImage]
    let onSelect: (URL) -> Void
    let onHover: (Bool) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 40, maximum: 40), spacing: 6, alignment: .top)
    ]

    var body: some View {
        ZStack {
            Color.white

            ScrollView {
                if images.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Žádné uložené vstupní obrázky")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Klikni na plus v hlavním poli a přidej první obrázek.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .padding(12)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(images) { image in
                            Button {
                                onSelect(image.fileURL)
                            } label: {
                                if let nsImage = image.nsImage {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Použít uložený vstupní obrázek")
                        }
                    }
                    .padding(9)
                }
            }
        }
        .frame(
            width: max(panelSize.width, 220),
            height: max(panelSize.height, 120),
            alignment: .topLeading
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.14), lineWidth: 1)
        }
        .onHover(perform: onHover)
    }
}

@MainActor
private final class SavedInputGalleryPanelController: NSObject, NSWindowDelegate {
    private static let widthKey = "inputGalleryPanel.width"
    private static let heightKey = "inputGalleryPanel.height"

    private var panel: NSPanel?
    private var closeTask: Task<Void, Never>?
    private var anchorHovered = false
    private var panelHovered = false

    func setAnchorHovered(
        _ hovered: Bool,
        anchorFrame: CGRect,
        images: [SavedInputImage],
        onSelect: @escaping (URL) -> Void
    ) {
        anchorHovered = hovered
        closeTask?.cancel()
        guard hovered else {
            scheduleClose()
            return
        }
        guard !anchorFrame.isEmpty else {
            close()
            return
        }
        show(anchorFrame: anchorFrame, images: images, onSelect: onSelect)
    }

    func close() {
        closeTask?.cancel()
        panel?.orderOut(nil)
        anchorHovered = false
        panelHovered = false
    }

    func refreshIfNeeded(
        anchorFrame: CGRect,
        images: [SavedInputImage],
        onSelect: @escaping (URL) -> Void
    ) {
        guard anchorHovered else { return }
        guard !anchorFrame.isEmpty else {
            close()
            return
        }
        show(anchorFrame: anchorFrame, images: images, onSelect: onSelect)
    }

    private func show(
        anchorFrame: CGRect,
        images: [SavedInputImage],
        onSelect: @escaping (URL) -> Void
    ) {
        let panel = panel ?? makePanel()
        let contentSize = panel.contentRect(forFrameRect: panel.frame).size
        let content = SavedInputGalleryPanelContent(
            panelSize: CGSize(width: contentSize.width, height: contentSize.height),
            images: images,
            onSelect: { [weak self] url in
                onSelect(url)
                self?.close()
            },
            onHover: { [weak self] hovered in self?.setPanelHovered(hovered) }
        )
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(origin: .zero, size: contentSize)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        position(panel, beside: anchorFrame)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let defaults = UserDefaults.standard
        let storedWidth = defaults.double(forKey: Self.widthKey)
        let storedHeight = defaults.double(forKey: Self.heightKey)
        let size = NSSize(
            width: storedWidth >= 220 ? storedWidth : 286,
            height: storedHeight >= 120 ? storedHeight : 148
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        panel.minSize = NSSize(width: 220, height: 120)
        panel.maxSize = NSSize(width: 900, height: 700)
        panel.collectionBehavior = [.fullScreenAuxiliary]
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, beside anchorFrame: CGRect) {
        let visibleFrame = panel.screen?.visibleFrame
            ?? NSScreen.screens.first(where: { $0.frame.intersects(anchorFrame) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? anchorFrame
        let size = panel.frame.size
        var origin = CGPoint(
            x: anchorFrame.maxX + 8,
            y: anchorFrame.midY - size.height / 2
        )
        if origin.x + size.width > visibleFrame.maxX {
            origin.x = anchorFrame.minX - size.width - 8
        }
        origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        origin.y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }

    private func setPanelHovered(_ hovered: Bool) {
        panelHovered = hovered
        closeTask?.cancel()
        if !hovered { scheduleClose() }
    }

    private func scheduleClose() {
        closeTask?.cancel()
        closeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled,
                  let self,
                  !self.anchorHovered,
                  !self.panelHovered else { return }
            self.panel?.orderOut(nil)
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel else { return }
        UserDefaults.standard.set(panel.frame.width, forKey: Self.widthKey)
        UserDefaults.standard.set(panel.frame.height, forKey: Self.heightKey)
    }
}

private struct ImageWellAnchorReader: NSViewRepresentable {
    let onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: AnchorView, context: Context) {
        nsView.onChange = onChange
        nsView.reportFrame()
    }

    final class AnchorView: NSView {
        var onChange: ((CGRect) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrame()
        }

        override func layout() {
            super.layout()
            reportFrame()
        }

        func reportFrame() {
            guard let window else { return }
            let frame = window.convertToScreen(convert(bounds, to: nil))
            DispatchQueue.main.async { [onChange] in onChange?(frame) }
        }
    }
}
