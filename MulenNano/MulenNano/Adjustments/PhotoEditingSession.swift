//
//  PhotoEditingSession.swift
//  MulenNano
//
//  Nedestruktivní editační session: drží stav úprav, filtr a oříznutí,
//  živě renderuje náhled přes CoreImage a po „Použít" vyrobí plné rozlišení.
//

import SwiftUI
import CoreImage
import Observation

@Observable
@MainActor
final class PhotoEditingSession {
    /// Původní načtený obrázek (zdroj pravdy — nikdy se nemění).
    private(set) var sourceImage: NSImage?
    private(set) var sourceCI: CIImage?

    var state: AdjustmentState = .init()
    var filter: FilterPreset = .original
    var crop: CropState = .init()

    /// Aktuální živý náhled (preview rozlišení).
    private(set) var previewImage: NSImage?
    var isRendering: Bool = false

    private var renderTask: Task<Void, Never>?
    private var renderTaskID: UUID?
    private var requestedRenderRevision: UInt64 = 0

    init(source: NSImage?) {
        self.sourceImage = source
        if let source,
           let tiff = source.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let ci = CIImage(bitmapImageRep: bitmap) {
            sourceCI = ci
            previewImage = source
        }
    }

    var hasSource: Bool { sourceCI != nil }
    var isPristine: Bool { state.isDefault && filter == .original && crop.isDefault }

    /// Sloučí rychlé změny posuvníků do jedné sekvenční renderovací fronty.
    func schedulePreviewRender() {
        requestedRenderRevision &+= 1
        guard renderTask == nil else { return }

        let taskID = UUID()
        renderTaskID = taskID
        renderTask = Task { [weak self] in
            guard let self else { return }
            isRendering = true

            while !Task.isCancelled {
                let revision = requestedRenderRevision
                let source = sourceCI
                let snapshot = state
                let activeFilter = filter
                let activeCrop = crop

                let rendered = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                    guard let source else { return nil }
                    let output = AdjustmentEngine.apply(
                        to: source,
                        state: snapshot,
                        filter: activeFilter,
                        crop: activeCrop
                    )
                    return AdjustmentEngine.renderPreview(output, maxDimension: 1000)
                }.value

                guard !Task.isCancelled else { break }
                if let rendered {
                    previewImage = rendered
                }

                guard revision != requestedRenderRevision else { break }
                await Task.yield()
            }

            if renderTaskID == taskID {
                isRendering = false
                renderTask = nil
                renderTaskID = nil
            }
        }
    }

    /// Vynulování všech úprav.
    func resetAll() {
        requestedRenderRevision &+= 1
        renderTask?.cancel()
        renderTask = nil
        renderTaskID = nil
        state = .init()
        filter = .original
        crop = .init()
        previewImage = sourceImage
        isRendering = false
    }

    /// Render v plném rozlišení (finální výsledek pro uložení).
    func renderFullRes() -> Data? {
        guard let ci = sourceCI else { return nil }
        let out = AdjustmentEngine.apply(to: ci, state: state, filter: filter, crop: crop)
        return AdjustmentEngine.pngData(out)
    }

    /// Souhrnná hodnota pro skupinový posuvník (Photos podobně sumarizuje Light/Color/ČB).
    func summary(for group: AdjustGroup) -> Double {
        switch group {
        case .light:  return state.lightSummary
        case .color:  return state.colorSummary
        case .bw:     return state.bwSummary
        }
    }
}

// MARK: - Skupiny úprav (rozbalitelné karty jako ve Photos)

enum AdjustGroup: CaseIterable {
    case light, color, bw

    var title: String {
        switch self {
        case .light: return "Světlo"
        case .color: return "Barva"
        case .bw:    return "Černobílá"
        }
    }

    var symbol: String {
        switch self {
        case .light: return "sun.max"
        case .color: return "drop.degreesign.fill"
        case .bw:    return "circle.lefthalf.filled"
        }
    }
}
