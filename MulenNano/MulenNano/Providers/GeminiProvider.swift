//
//  GeminiProvider.swift
//  MulenNano
//
//  Implementace AIProvider pro Google Gemini (image generování).
//  Replikuje volání z webové Mulen nano: safety settings, grounding a aspect ratio.
//

import Foundation
import OSLog

struct GroundingLink: Hashable, Codable {
    let url: String
    let title: String
}

struct GeminiProvider: AIProvider {
    var kind: AIProviderKind { .gemini }
    var keychainAccount: String { "gemini" }

    // Generování používá výhradně dva obrazové modely řady Gemini 3.
    private static let flash = "gemini-3.1-flash-image"
    private static let pro = "gemini-3-pro-image"
    private static let logger = Logger(subsystem: "com.mulen.MulenNano", category: "GeminiProvider")

    private func endpoint(model: String, apiKey: String) -> URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
    }

    private func candidates(preferred: String, allowFallback: Bool) -> [String] {
        let preferred = (preferred == Self.flash || preferred == Self.pro) ? preferred : Self.flash
        guard allowFallback else { return [preferred] }
        let other = preferred == Self.flash ? Self.pro : Self.flash
        return [preferred, other]
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

        var lastError: Error = ProviderError.noImageInResponse
        for model in candidates(preferred: request.modelID, allowFallback: request.allowModelFallback) {
            do {
                let bodyData = try requestBodyData(for: request, model: model)
                Self.logger.info("Image request started model=\(model, privacy: .public)")
                let output = try await callModel(model, bodyData: bodyData, apiKey: apiKey)
                return output.cropped(to: request.inputImages.first?.pixelAspectRatio)
            } catch let error {
                lastError = error
                let msg = error.localizedDescription.lowercased()
                let retryable = msg.contains("503") || msg.contains("overloaded")
                    || msg.contains("unavailable") || msg.contains("high demand")
                let missingImage: Bool
                if case ProviderError.noImageInResponse = error {
                    missingImage = true
                } else {
                    missingImage = false
                }
                if !retryable && !missingImage { throw error }
                // Při dočasné chybě nebo prázdné odpovědi zkus druhý model řady Gemini 3.
            }
        }
        throw lastError
    }

    private func requestBodyData(for request: GenerationRequest, model: String) throws -> Data {
        var parts: [[String: Any]] = request.inputImages.map { image in
            ["inlineData": ["data": image.data.base64EncodedString(), "mimeType": image.mimeType]]
        }
        parts.append(["text": request.prompt])

        var imageConfig: [String: Any] = [:]
        if let aspectRatio = request.aspectRatio, aspectRatio != "Original" {
            imageConfig["aspectRatio"] = aspectRatio
        }
        if let resolution = request.resolution {
            imageConfig["imageSize"] = resolution
        }

        var generationConfig: [String: Any] = ["responseModalities": ["IMAGE"]]
        if !imageConfig.isEmpty {
            generationConfig["imageConfig"] = imageConfig
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
        return try JSONSerialization.data(withJSONObject: body)
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
            let summary = responseSummary(json)
            Self.logger.error("No candidates model=\(model, privacy: .public) details=\(summary, privacy: .public)")
            throw ProviderError.noImageInResponse
        }

        for candidate in candidatesArr {
            let content = candidate["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]] ?? []
            for part in parts {
                let inlineData = (part["inlineData"] as? [String: Any])
                    ?? (part["inline_data"] as? [String: Any])
                if let inlineData,
                   let b64 = inlineData["data"] as? String,
                   let imageData = Data(base64Encoded: b64) {
                    let mime = (inlineData["mimeType"] as? String)
                        ?? (inlineData["mime_type"] as? String)
                        ?? "image/png"
                    let links = extractGrounding(candidate)
                    Self.logger.info("Image received model=\(model, privacy: .public) bytes=\(imageData.count)")
                    return GenerationOutput(imageData: imageData, mimeType: mime, modelID: model, groundingLinks: links)
                }
            }
        }
        let summary = responseSummary(json)
        Self.logger.error("No image model=\(model, privacy: .public) details=\(summary, privacy: .public)")
        throw ProviderError.noImageInResponse
    }

    private func responseSummary(_ json: [String: Any]?) -> String {
        guard let json else { return "invalid-json" }
        var details: [String] = []
        if let feedback = json["promptFeedback"] as? [String: Any],
           let blockReason = feedback["blockReason"] as? String {
            details.append("blockReason=\(blockReason)")
        }
        let candidates = json["candidates"] as? [[String: Any]] ?? []
        for (index, candidate) in candidates.enumerated() {
            if let finishReason = candidate["finishReason"] as? String {
                details.append("candidate\(index).finishReason=\(finishReason)")
            }
            let parts = (candidate["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
            let partTypes = Set(parts.flatMap(\.keys)).sorted().joined(separator: ",")
            if !partTypes.isEmpty {
                details.append("candidate\(index).partTypes=\(partTypes)")
            }
            let blockedCategories: [String] = (candidate["safetyRatings"] as? [[String: Any]] ?? []).compactMap { rating in
                guard rating["blocked"] as? Bool == true else { return nil }
                return rating["category"] as? String
            }
            if !blockedCategories.isEmpty {
                details.append("candidate\(index).blocked=\(blockedCategories.joined(separator: ","))")
            }
        }
        return details.isEmpty ? "keys=\(json.keys.sorted().joined(separator: ","))" : details.joined(separator: ";")
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
