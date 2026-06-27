//
//  GeminiProvider.swift
//  MulenNano
//
//  Implementace AIProvider pro Google Gemini (image generování).
//  Replikuje volání z webové Mulen nano: safety settings, grounding, aspect ratio, fallback modelů.
//

import Foundation

struct GroundingLink: Hashable, Codable {
    let url: String
    let title: String
}

struct GeminiProvider: AIProvider {
    var kind: AIProviderKind { .gemini }
    var keychainAccount: String { "gemini" }

    // Modely a fallback řetězec (dle provider-generate.cjs).
    private static let flash = "gemini-3.1-flash-image-preview"
    private static let pro = "gemini-3-pro-image-preview"
    private static let fallback = "gemini-2.5-flash-image"

    private func endpoint(model: String, apiKey: String) -> URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
    }

    private func candidates(preferred: String) -> [String] {
        let preferred = (preferred == Self.flash || preferred == Self.pro) ? preferred : Self.flash
        let other = preferred == Self.flash ? Self.pro : Self.flash
        var seen = Set<String>()
        return [preferred, other, Self.fallback].filter { seen.insert($0).inserted }
    }

    func validate(apiKey: String) async -> Bool {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    func generate(_ request: GenerationRequest, apiKey: String) async throws -> GenerationOutput {
        guard !apiKey.isEmpty else { throw ProviderError.missingKey }

        // Parts: vstupní obrázky (v pořadí source→style→asset) + text.
        var parts: [[String: Any]] = request.inputImages.map { image in
            ["inlineData": ["data": image.data.base64EncodedString(), "mimeType": image.mimeType]]
        }
        parts.append(["text": request.prompt])

        var generationConfig: [String: Any] = ["responseModalities": ["IMAGE"]]
        if let ar = request.aspectRatio, ar != "Original" {
            generationConfig["imageConfig"] = ["aspectRatio": ar]
        }

        var body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": generationConfig,
            "safetySettings": [
                ["category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_ONLY_HIGH"],
            ],
        ]
        if request.grounding {
            body["tools"] = [["googleSearch": [String: Any]()]]
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error = ProviderError.noImageInResponse
        for model in candidates(preferred: request.modelID) {
            do {
                return try await callModel(model, bodyData: bodyData, apiKey: apiKey)
            } catch let error {
                lastError = error
                let msg = error.localizedDescription.lowercased()
                let retryable = msg.contains("503") || msg.contains("overloaded")
                    || msg.contains("unavailable") || msg.contains("high demand")
                if !retryable { throw error }
                // jinak zkus další model v řetězci
            }
        }
        throw lastError
    }

    private func callModel(_ model: String, bodyData: Data, apiKey: String) async throws -> GenerationOutput {
        var urlRequest = URLRequest(url: endpoint(model: model, apiKey: apiKey))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.api("Žádná odpověď serveru.")
        }
        guard http.statusCode == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String)
                ?? "Gemini API chyba (\(http.statusCode))"
            throw ProviderError.api(message)
        }

        guard let candidatesArr = json?["candidates"] as? [[String: Any]] else {
            throw ProviderError.noImageInResponse
        }

        for candidate in candidatesArr {
            let content = candidate["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]] ?? []
            for part in parts {
                if let inlineData = part["inlineData"] as? [String: Any],
                   let b64 = inlineData["data"] as? String,
                   let imageData = Data(base64Encoded: b64) {
                    let mime = (inlineData["mimeType"] as? String) ?? "image/png"
                    let links = extractGrounding(candidate)
                    return GenerationOutput(imageData: imageData, mimeType: mime, modelID: model, groundingLinks: links)
                }
            }
        }
        throw ProviderError.noImageInResponse
    }

    private func extractGrounding(_ candidate: [String: Any]) -> [GroundingLink] {
        guard let meta = candidate["groundingMetadata"] as? [String: Any],
              let chunks = meta["groundingChunks"] as? [[String: Any]] else { return [] }
        return chunks.compactMap { chunk in
            guard let web = chunk["web"] as? [String: Any],
                  let uri = web["uri"] as? String else { return nil }
            return GroundingLink(url: uri, title: (web["title"] as? String) ?? uri)
        }
    }
}
