//
//  LibraryStore.swift
//  MulenNano
//
//  Knihovna vygenerovaných obrázků + koš + kolekce, perzistentní na disku.
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
    var collectionIDs: Set<UUID>
    var groundingLinks: [GroundingLink] = []
    var revisions: [LibraryImageRevision] = []
    var undoneRevisions: [LibraryImageRevision] = []

    var nsImage: NSImage? { NSImage(contentsOf: fileURL) }
    var imageData: Data? { try? Data(contentsOf: fileURL) }
}

struct AppCollection: Identifiable, Hashable {
    let id: UUID
    var name: String
}

@Observable
final class LibraryStore {
    private(set) var images: [LibraryImage] = []
    private(set) var trashed: [LibraryImage] = []
    private(set) var collections: [AppCollection] = []
    private(set) var folder: URL

    private let fileManager = FileManager.default
    private static let folderKey = "mulen.storageFolder"

    init() {
        self.folder = LibraryStore.resolveFolder()
        ensureFolders()
        load()
    }

    // MARK: Cesty
    private var imagesFolder: URL { folder.appendingPathComponent("images", isDirectory: true) }
    private var indexURL: URL { folder.appendingPathComponent("library.json") }

    private static func resolveFolder() -> URL {
        if let path = UserDefaults.standard.string(forKey: folderKey) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("MulenNano", isDirectory: true)
    }

    private func ensureFolders() {
        try? fileManager.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
    }

    // MARK: Změna složky
    func setFolder(_ newFolder: URL) {
        // Přesun stávajících souborů do nové složky.
        let newImages = newFolder.appendingPathComponent("images", isDirectory: true)
        try? fileManager.createDirectory(at: newImages, withIntermediateDirectories: true)
        for img in images + trashed {
            let dest = newImages.appendingPathComponent(img.fileURL.lastPathComponent)
            if !fileManager.fileExists(atPath: dest.path) {
                try? fileManager.copyItem(at: img.fileURL, to: dest)
            }
        }
        folder = newFolder
        UserDefaults.standard.set(newFolder.path, forKey: Self.folderKey)
        ensureFolders()
        // Přepočítat fileURL na novou složku.
        images = images.map { remap($0) }
        trashed = trashed.map { remap($0) }
        save()
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
                            collectionIDs: img.collectionIDs, groundingLinks: img.groundingLinks,
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
        try? imageData.write(to: url)
        let image = LibraryImage(id: id, fileURL: url, prompt: prompt, modelID: modelID,
                                 providerName: providerName,
                                 aspectRatio: aspectRatio, resolution: resolution,
                                 createdAt: Date(), updatedAt: Date(),
                                 runID: runID, variantLabel: variantLabel,
                                 collectionIDs: [], groundingLinks: groundingLinks)
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
        guard let idx = images.firstIndex(where: { $0.id == id }) else { return }
        trashed.insert(images.remove(at: idx), at: 0)
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

    // MARK: Kolekce
    @discardableResult
    func createCollection(_ name: String) -> AppCollection {
        let c = AppCollection(id: UUID(), name: name)
        collections.append(c)
        save()
        return c
    }

    func deleteCollection(_ id: UUID) {
        collections.removeAll { $0.id == id }
        for i in images.indices { images[i].collectionIDs.remove(id) }
        save()
    }

    func toggleMembership(imageID: UUID, collectionID: UUID) {
        guard let idx = images.firstIndex(where: { $0.id == imageID }) else { return }
        if images[idx].collectionIDs.contains(collectionID) {
            images[idx].collectionIDs.remove(collectionID)
        } else {
            images[idx].collectionIDs.insert(collectionID)
        }
        save()
    }

    func images(in collectionID: UUID) -> [LibraryImage] {
        images.filter { $0.collectionIDs.contains(collectionID) }
    }

    // MARK: Perzistence
    private func save() {
        let index = LibraryIndex(
            images: images.map(LibraryIndex.Meta.init),
            trashed: trashed.map(LibraryIndex.Meta.init),
            collections: collections.map { LibraryIndex.CollectionMeta(id: $0.id, name: $0.name) }
        )
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: indexURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(LibraryIndex.self, from: data) else { return }
        images = index.images.map { $0.toImage(folder: imagesFolder) }
        trashed = index.trashed.map { $0.toImage(folder: imagesFolder) }
        collections = index.collections.map { AppCollection(id: $0.id, name: $0.name) }
    }
}

// MARK: - Persistovaný index
private struct LibraryIndex: Codable {
    var images: [Meta]
    var trashed: [Meta]
    var collections: [CollectionMeta]

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
        var collectionIDs: [UUID]
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
            collectionIDs = Array(img.collectionIDs)
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
                         collectionIDs: Set(collectionIDs),
                         groundingLinks: groundingLinks,
                         revisions: revisions,
                         undoneRevisions: undoneRevisions)
        }
    }

    struct CollectionMeta: Codable {
        var id: UUID
        var name: String
    }
}
