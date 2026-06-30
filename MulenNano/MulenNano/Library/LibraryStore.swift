//
//  LibraryStore.swift
//  MulenNano
//
//  Knihovna vygenerovaných obrázků + koš, perzistentní na disku.
//  Obrázky = soubory PNG ve zvolené složce; metadata = library.json.
//

import SwiftUI
import Observation

struct LibraryImageRevision: Codable, Hashable {
    var fileName: String
    var prompt: String
    var modelID: String
    var providerName: String?
    var aspectRatio: String?
    var resolution: String?
    var groundingLinks: [GroundingLink] = []
    var savedAt: Date
}

struct LibraryImage: Identifiable, Hashable {
    let id: UUID
    let fileURL: URL
    var prompt: String
    var modelID: String
    var providerName: String?
    var aspectRatio: String?
    var resolution: String?
    let createdAt: Date
    var updatedAt: Date
    var runID: UUID?
    var variantLabel: String?
    var groundingLinks: [GroundingLink] = []
    var revisions: [LibraryImageRevision] = []
    var undoneRevisions: [LibraryImageRevision] = []

    var nsImage: NSImage? { NSImage(contentsOf: fileURL) }
    var imageData: Data? { try? Data(contentsOf: fileURL) }
}

struct SavedInputImage: Identifiable, Hashable {
    let id: UUID
    let fileURL: URL
    let createdAt: Date

    var nsImage: NSImage? { NSImage(contentsOf: fileURL) }
}

@Observable
final class LibraryStore {
    private(set) var images: [LibraryImage] = []
    private(set) var trashed: [LibraryImage] = []
    private(set) var inputImages: [SavedInputImage] = []
    private(set) var folder: URL
    private(set) var lastErrorMessage: String?

    private let fileManager = FileManager.default
    private static let folderKey = "mulen.storageFolder"

    init() {
        self.folder = LibraryStore.resolveFolder()
        ensureFolders()
        load()
        loadInputImages()
    }

    // MARK: Cesty
    private var imagesFolder: URL { folder.appendingPathComponent("images", isDirectory: true) }
    private var inputImagesFolder: URL { folder.appendingPathComponent("inputs", isDirectory: true) }
    private var indexURL: URL { folder.appendingPathComponent("library.json") }
    private var inputIndexURL: URL { folder.appendingPathComponent("inputs.json") }

    private static func resolveFolder() -> URL {
        if let path = UserDefaults.standard.string(forKey: folderKey) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("MulenNano", isDirectory: true)
    }

    private func ensureFolders() {
        do {
            try fileManager.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: inputImagesFolder, withIntermediateDirectories: true)
            lastErrorMessage = nil
        } catch {
            recordError("Nepodařilo se připravit složky knihovny: \(error.localizedDescription)")
        }
    }

    // MARK: Změna složky
    func setFolder(_ newFolder: URL) {
        do {
            // Přesun stávajících souborů do nové složky.
            let newImages = newFolder.appendingPathComponent("images", isDirectory: true)
            let newInputs = newFolder.appendingPathComponent("inputs", isDirectory: true)
            try fileManager.createDirectory(at: newImages, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: newInputs, withIntermediateDirectories: true)

            for img in images + trashed {
                let dest = newImages.appendingPathComponent(img.fileURL.lastPathComponent)
                if !fileManager.fileExists(atPath: dest.path) {
                    try fileManager.copyItem(at: img.fileURL, to: dest)
                }
            }
            for input in inputImages {
                let destination = newInputs.appendingPathComponent(input.fileURL.lastPathComponent)
                if !fileManager.fileExists(atPath: destination.path) {
                    try fileManager.copyItem(at: input.fileURL, to: destination)
                }
            }

            folder = newFolder
            UserDefaults.standard.set(newFolder.path, forKey: Self.folderKey)
            ensureFolders()
            images = images.map { remap($0) }
            trashed = trashed.map { remap($0) }
            inputImages = inputImages.map {
                SavedInputImage(
                    id: $0.id,
                    fileURL: inputImagesFolder.appendingPathComponent($0.fileURL.lastPathComponent),
                    createdAt: $0.createdAt
                )
            }
            save()
            saveInputImages()
            lastErrorMessage = nil
        } catch {
            recordError("Nepodařilo se změnit složku knihovny: \(error.localizedDescription)")
        }
    }

    private func remap(_ img: LibraryImage) -> LibraryImage {
        var copy = img
        copy = LibraryImage(id: img.id,
                            fileURL: imagesFolder.appendingPathComponent(img.fileURL.lastPathComponent),
                            prompt: img.prompt, modelID: img.modelID,
                            providerName: img.providerName,
                            aspectRatio: img.aspectRatio, resolution: img.resolution,
                            createdAt: img.createdAt, updatedAt: img.updatedAt,
                            runID: img.runID, variantLabel: img.variantLabel,
                            groundingLinks: img.groundingLinks,
                            revisions: img.revisions, undoneRevisions: img.undoneRevisions)
        return copy
    }

    // MARK: Obrázky
    @discardableResult
    func store(imageData: Data, prompt: String, modelID: String,
               runID: UUID? = nil, variantLabel: String? = nil,
               providerName: String? = nil,
               aspectRatio: String? = nil, resolution: String? = nil,
               groundingLinks: [GroundingLink] = []) -> LibraryImage {
        let id = UUID()
        let url = imagesFolder.appendingPathComponent("\(id.uuidString).png")
        do {
            try imageData.write(to: url, options: .atomic)
            lastErrorMessage = nil
        } catch {
            recordError("Nepodařilo se uložit obrázek do knihovny: \(error.localizedDescription)")
        }
        let image = LibraryImage(id: id, fileURL: url, prompt: prompt, modelID: modelID,
                                 providerName: providerName,
                                 aspectRatio: aspectRatio, resolution: resolution,
                                 createdAt: Date(), updatedAt: Date(),
                                 runID: runID, variantLabel: variantLabel,
                                 groundingLinks: groundingLinks)
        images.insert(image, at: 0)
        save()
        return image
    }

    func replaceImage(
        _ id: UUID,
        imageData: Data,
        prompt: String,
        modelID: String,
        providerName: String? = nil,
        aspectRatio: String? = nil,
        resolution: String? = nil,
        groundingLinks: [GroundingLink] = []
    ) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        var image = images[index]

        let revisionFileName = "\(id.uuidString)-rev-\(Int(Date().timeIntervalSince1970 * 1000)).png"
        let revisionURL = imagesFolder.appendingPathComponent(revisionFileName)
        if let currentData = try? Data(contentsOf: image.fileURL) {
            try? currentData.write(to: revisionURL)
            image.revisions.append(
                LibraryImageRevision(
                    fileName: revisionFileName,
                    prompt: image.prompt,
                    modelID: image.modelID,
                    providerName: image.providerName,
                    aspectRatio: image.aspectRatio,
                    resolution: image.resolution,
                    groundingLinks: image.groundingLinks,
                    savedAt: image.updatedAt
                )
            )
        }

        try? imageData.write(to: image.fileURL)
        image.prompt = prompt
        image.modelID = modelID
        image.providerName = providerName
        image.aspectRatio = aspectRatio
        image.resolution = resolution
        image.updatedAt = Date()
        image.groundingLinks = groundingLinks
        image.undoneRevisions.removeAll()
        images[index] = image
        save()
    }

    func undoLastRevision(_ id: UUID) {
        guard let index = images.firstIndex(where: { $0.id == id }),
              let revision = images[index].revisions.popLast() else { return }

        var image = images[index]
        let redoFileName = "\(id.uuidString)-redo-\(Int(Date().timeIntervalSince1970 * 1000)).png"
        let redoURL = imagesFolder.appendingPathComponent(redoFileName)
        if let currentData = try? Data(contentsOf: image.fileURL) {
            try? currentData.write(to: redoURL)
            image.undoneRevisions.append(
                LibraryImageRevision(
                    fileName: redoFileName,
                    prompt: image.prompt,
                    modelID: image.modelID,
                    providerName: image.providerName,
                    aspectRatio: image.aspectRatio,
                    resolution: image.resolution,
                    groundingLinks: image.groundingLinks,
                    savedAt: image.updatedAt
                )
            )
        }

        let revisionURL = imagesFolder.appendingPathComponent(revision.fileName)
        if let data = try? Data(contentsOf: revisionURL) {
            try? data.write(to: image.fileURL)
        }

        image.prompt = revision.prompt
        image.modelID = revision.modelID
        image.providerName = revision.providerName
        image.aspectRatio = revision.aspectRatio
        image.resolution = revision.resolution
        image.groundingLinks = revision.groundingLinks
        image.updatedAt = Date()
        images[index] = image

        try? fileManager.removeItem(at: revisionURL)
        save()
    }

    func redoLastRevision(_ id: UUID) {
        guard let index = images.firstIndex(where: { $0.id == id }),
              let revision = images[index].undoneRevisions.popLast() else { return }

        var image = images[index]
        let undoFileName = "\(id.uuidString)-rev-\(Int(Date().timeIntervalSince1970 * 1000)).png"
        let undoURL = imagesFolder.appendingPathComponent(undoFileName)
        if let currentData = try? Data(contentsOf: image.fileURL) {
            try? currentData.write(to: undoURL)
            image.revisions.append(
                LibraryImageRevision(
                    fileName: undoFileName,
                    prompt: image.prompt,
                    modelID: image.modelID,
                    providerName: image.providerName,
                    aspectRatio: image.aspectRatio,
                    resolution: image.resolution,
                    groundingLinks: image.groundingLinks,
                    savedAt: image.updatedAt
                )
            )
        }

        let revisionURL = imagesFolder.appendingPathComponent(revision.fileName)
        if let data = try? Data(contentsOf: revisionURL) {
            try? data.write(to: image.fileURL)
        }

        image.prompt = revision.prompt
        image.modelID = revision.modelID
        image.providerName = revision.providerName
        image.aspectRatio = revision.aspectRatio
        image.resolution = revision.resolution
        image.groundingLinks = revision.groundingLinks
        image.updatedAt = Date()
        images[index] = image

        try? fileManager.removeItem(at: revisionURL)
        save()
    }

    func moveToTrash(_ id: UUID) {
        moveToTrash([id])
    }

    func moveToTrash(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let moving = images.filter { ids.contains($0.id) }
        guard !moving.isEmpty else { return }
        images.removeAll { ids.contains($0.id) }
        trashed.insert(contentsOf: moving, at: 0)
        save()
    }

    func restore(_ id: UUID) {
        guard let idx = trashed.firstIndex(where: { $0.id == id }) else { return }
        images.insert(trashed.remove(at: idx), at: 0)
        save()
    }

    func emptyTrash() {
        for img in trashed { try? fileManager.removeItem(at: img.fileURL) }
        trashed.removeAll()
        save()
    }

    // MARK: Vstupní obrázky
    @discardableResult
    func importInputImage(from sourceURL: URL) -> URL? {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: sourceURL), NSImage(data: data) != nil else { return nil }
        if let existing = inputImages.first(where: { (try? Data(contentsOf: $0.fileURL)) == data }) {
            return existing.fileURL
        }

        let id = UUID()
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        let destination = inputImagesFolder.appendingPathComponent("\(id.uuidString).\(fileExtension)")
        guard (try? data.write(to: destination, options: .atomic)) != nil else { return nil }

        let input = SavedInputImage(id: id, fileURL: destination, createdAt: Date())
        inputImages.insert(input, at: 0)
        saveInputImages()
        return destination
    }

    func removeInputImage(_ id: UUID) {
        guard let index = inputImages.firstIndex(where: { $0.id == id }) else { return }
        let image = inputImages.remove(at: index)
        try? fileManager.removeItem(at: image.fileURL)
        saveInputImages()
    }

    // MARK: Perzistence
    private func save() {
        let index = LibraryIndex(
            images: images.map(LibraryIndex.Meta.init),
            trashed: trashed.map(LibraryIndex.Meta.init)
        )
        do {
            let data = try JSONEncoder().encode(index)
            try data.write(to: indexURL, options: .atomic)
            lastErrorMessage = nil
        } catch {
            recordError("Nepodařilo se uložit metadata knihovny: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(LibraryIndex.self, from: data) else { return }
        images = index.images.map { $0.toImage(folder: imagesFolder) }
        trashed = index.trashed.map { $0.toImage(folder: imagesFolder) }
    }

    private func saveInputImages() {
        let index = SavedInputIndex(
            images: inputImages.map {
                SavedInputIndex.Meta(id: $0.id, fileName: $0.fileURL.lastPathComponent, createdAt: $0.createdAt)
            }
        )
        do {
            let data = try JSONEncoder().encode(index)
            try data.write(to: inputIndexURL, options: .atomic)
            lastErrorMessage = nil
        } catch {
            recordError("Nepodařilo se uložit vstupní obrázky: \(error.localizedDescription)")
        }
    }

    private func loadInputImages() {
        guard let data = try? Data(contentsOf: inputIndexURL),
              let index = try? JSONDecoder().decode(SavedInputIndex.self, from: data) else { return }
        inputImages = index.images.compactMap { meta in
            let url = inputImagesFolder.appendingPathComponent(meta.fileName)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return SavedInputImage(id: meta.id, fileURL: url, createdAt: meta.createdAt)
        }
    }

    private func recordError(_ message: String) {
        lastErrorMessage = message
    }
}

private struct SavedInputIndex: Codable {
    var images: [Meta]

    struct Meta: Codable {
        var id: UUID
        var fileName: String
        var createdAt: Date
    }
}

// MARK: - Persistovaný index
private struct LibraryIndex: Codable {
    var images: [Meta]
    var trashed: [Meta]

    struct Meta: Codable {
        var id: UUID
        var fileName: String
        var prompt: String
        var modelID: String
        var providerName: String?
        var aspectRatio: String?
        var resolution: String?
        var createdAt: Date
        var updatedAt: Date
        var runID: UUID?
        var variantLabel: String?
        var groundingLinks: [GroundingLink]
        var revisions: [LibraryImageRevision]
        var undoneRevisions: [LibraryImageRevision]

        nonisolated init(_ img: LibraryImage) {
            id = img.id
            fileName = img.fileURL.lastPathComponent
            prompt = img.prompt
            modelID = img.modelID
            providerName = img.providerName
            aspectRatio = img.aspectRatio
            resolution = img.resolution
            createdAt = img.createdAt
            updatedAt = img.updatedAt
            runID = img.runID
            variantLabel = img.variantLabel
            groundingLinks = img.groundingLinks
            revisions = img.revisions
            undoneRevisions = img.undoneRevisions
        }

        nonisolated func toImage(folder: URL) -> LibraryImage {
            LibraryImage(id: id,
                         fileURL: folder.appendingPathComponent(fileName),
                         prompt: prompt, modelID: modelID,
                         providerName: providerName,
                         aspectRatio: aspectRatio, resolution: resolution,
                         createdAt: createdAt, updatedAt: updatedAt,
                         runID: runID, variantLabel: variantLabel,
                         groundingLinks: groundingLinks,
                         revisions: revisions,
                         undoneRevisions: undoneRevisions)
        }
    }
}
