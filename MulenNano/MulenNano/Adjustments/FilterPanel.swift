//
//  FilterPanel.swift
//  MulenNano
//
//  Záložka „Filtr" — mřížka náhledů filtrů přesně jako Apple Photos:
//  Originál / Mono / Tón / Noir / Blednutí / Chrome / Proces / Přenos / Instant / Drama…
//

import SwiftUI
import CoreImage

struct FilterPanel: View {
    @Bindable var session: PhotoEditingSession

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 96), spacing: DS.Space.s, alignment: .top)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: DS.Space.m) {
                ForEach(FilterPreset.allCases) { preset in
                    filterTile(preset)
                }
            }
            .padding(DS.Space.s)
        }
    }

    private func filterTile(_ preset: FilterPreset) -> some View {
        let isSelected = session.filter == preset
        return Button {
            session.filter = preset
            session.schedulePreviewRender()
        } label: {
            VStack(spacing: DS.Space.xxs) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(DS.Palette.fieldBackground)
                    FilterThumbnail(source: session.sourceCI, preset: preset, size: 72)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
                    if isSelected {
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .aspectRatio(1, contentMode: .fit)

                Text(preset.rawValue)
                    .font(.dsSmall)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Thumbnail s aplikovaným filtrem, cachovaný.
struct FilterThumbnail: View {
    let source: CIImage?
    let preset: FilterPreset
    let size: CGFloat

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: preset) {
            guard let source else { return }
            let emptyState = AdjustmentState()
            let emptyCrop = CropState()
            let target = size
            let rendered = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                let out = AdjustmentEngine.apply(to: source, state: emptyState, filter: preset, crop: emptyCrop)
                return AdjustmentEngine.renderPreview(out, maxDimension: target * 2)
            }.value
            await MainActor.run { self.image = rendered }
        }
    }
}
