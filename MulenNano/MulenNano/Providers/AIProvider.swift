//
//  AIProvider.swift
//  MulenNano
//
//  Jádro vyměnitelnosti — protokol, který implementuje každý AI poskytovatel.
//  UI nikdy nezná konkrétního providera, jen tento protokol a registr.
//

import Foundation

/// Vstupní obrázek pro generování (raw data + MIME typ).
struct InputImage {
    let data: Data
    let mimeType: String
}

/// Požadavek na generování — nezávislý na konkrétním provideru.
struct GenerationRequest {
    var prompt: String
    var inputImages: [InputImage] = []
    var modelID: String
    var aspectRatio: String? = nil
    var resolution: String? = nil
    var grounding: Bool = false
}

/// Výsledek generování — surová data obrázku.
struct GenerationOutput {
    let imageData: Data
    let mimeType: String
    let modelID: String
    var groundingLinks: [GroundingLink] = []
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

/// Jedna AI-vygenerovaná varianta promptu (pro Interpretaci).
struct PromptVariant {
    let variant: String
    let approach: String
    let prompt: String
}

protocol AIProvider {
    var kind: AIProviderKind { get }
    /// Klíč pro uložení v Keychain.
    var keychainAccount: String { get }
    func validate(apiKey: String) async -> Bool
    func generate(_ request: GenerationRequest, apiKey: String) async throws -> GenerationOutput

    /// Textové operace (výchozí: nepodporováno).
    func enhancePrompt(_ prompt: String, apiKey: String) async throws -> String
    func promptVariants(_ prompt: String, apiKey: String) async throws -> [PromptVariant]
}

extension AIProvider {
    func enhancePrompt(_ prompt: String, apiKey: String) async throws -> String {
        throw ProviderError.notImplemented(kind.rawValue)
    }
    func promptVariants(_ prompt: String, apiKey: String) async throws -> [PromptVariant] {
        throw ProviderError.notImplemented(kind.rawValue)
    }
}
