//
//  AIProvider.swift
//  MulenNano
//
//  Jádro vyměnitelnosti — protokol, který implementuje každý AI poskytovatel.
//  UI nikdy nezná konkrétního providera, jen tento protokol a registr.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ProviderOptionValue: Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var jsonValue: Any {
        switch self {
        case .string(let value): value
        case .int(let value): value
        case .double(let value): value
        case .bool(let value): value
        }
    }
}

/// Vstupní obrázek pro generování (raw data + MIME typ).
struct InputImage {
    let data: Data
    let mimeType: String

    var pixelAspectRatio: Double? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else { return nil }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return (5...8).contains(orientation) ? height / width : width / height
    }

    var closestSupportedAspectRatio: String? {
        guard let sourceRatio = pixelAspectRatio else { return nil }
        let supported: [(label: String, value: Double)] = [
            ("1:1", 1),
            ("2:3", 2.0 / 3.0),
            ("3:2", 3.0 / 2.0),
            ("4:5", 4.0 / 5.0),
            ("5:4", 5.0 / 4.0),
            ("3:4", 3.0 / 4.0),
            ("4:3", 4.0 / 3.0),
            ("9:16", 9.0 / 16.0),
            ("16:9", 16.0 / 9.0),
        ]
        return supported.min {
            abs(log($0.value / sourceRatio)) < abs(log($1.value / sourceRatio))
        }?.label
    }
}

/// Požadavek na generování — nezávislý na konkrétním provideru.
struct GenerationRequest {
    var prompt: String
    var inputImages: [InputImage]
    var modelID: String
    var aspectRatio: String?
    var resolution: String?
    var grounding: Bool
    var allowModelFallback: Bool
    var providerOptions: [String: ProviderOptionValue]

    init(
        prompt: String,
        inputImages: [InputImage] = [],
        modelID: String,
        aspectRatio: String? = nil,
        resolution: String? = nil,
        grounding: Bool = false,
        allowModelFallback: Bool = true,
        providerOptions: [String: ProviderOptionValue] = [:]
    ) {
        self.prompt = prompt
        self.inputImages = inputImages
        self.modelID = modelID
        self.aspectRatio = inputImages.first?.closestSupportedAspectRatio ?? aspectRatio
        self.resolution = resolution
        self.grounding = grounding
        self.allowModelFallback = allowModelFallback
        self.providerOptions = providerOptions
    }
}

/// Výsledek generování — surová data obrázku.
struct GenerationOutput {
    let imageData: Data
    let mimeType: String
    let modelID: String
    var groundingLinks: [GroundingLink] = []

    func cropped(to targetAspectRatio: Double?) -> GenerationOutput {
        guard let targetAspectRatio,
              let croppedData = ImageAspectNormalizer.centerCrop(imageData, to: targetAspectRatio) else {
            return self
        }
        return GenerationOutput(
            imageData: croppedData,
            mimeType: "image/png",
            modelID: modelID,
            groundingLinks: groundingLinks
        )
    }
}

private enum ImageAspectNormalizer {
    static func centerCrop(_ data: Data, to targetRatio: Double) -> Data? {
        guard targetRatio > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.height > 0 else { return nil }

        let currentRatio = Double(image.width) / Double(image.height)
        guard abs(log(currentRatio / targetRatio)) > 0.005 else { return nil }

        let cropRect: CGRect
        if currentRatio > targetRatio {
            let width = min(CGFloat(image.width), CGFloat(image.height) * targetRatio)
            cropRect = CGRect(x: (CGFloat(image.width) - width) / 2, y: 0, width: width, height: CGFloat(image.height))
        } else {
            let height = min(CGFloat(image.height), CGFloat(image.width) / targetRatio)
            cropRect = CGRect(x: 0, y: (CGFloat(image.height) - height) / 2, width: CGFloat(image.width), height: height)
        }

        guard let cropped = image.cropping(to: cropRect.integral),
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                destinationData,
                UTType.png.identifier as CFString,
                1,
                nil
              ) else { return nil }
        CGImageDestinationAddImage(destination, cropped, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }
}

enum ProviderError: LocalizedError {
    case missingKey
    case notImplemented(String)
    case noImageInResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:            "Chybí API klíč. Zadej ho v Nastavení."
        case .notImplemented(let p): "\(p) zatím není napojený."
        case .noImageInResponse:     "Odpověď neobsahovala obrázek."
        case .api(let message):      message
        }
    }
}

protocol AIProvider {
    var kind: AIProviderKind { get }
    /// Klíč pro uložení v Keychain.
    var keychainAccount: String { get }
    func validate(apiKey: String) async -> Bool
    func generate(_ request: GenerationRequest, apiKey: String) async throws -> GenerationOutput

    /// Textové operace (výchozí: nepodporováno).
    func enhancePrompt(_ prompt: String, apiKey: String) async throws -> String
}

extension AIProvider {
    func enhancePrompt(_ prompt: String, apiKey: String) async throws -> String {
        throw ProviderError.notImplemented(kind.rawValue)
    }
}
