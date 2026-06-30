//
//  OpenAIProvider.swift
//  MulenNano
//
//  Implementace AIProvider pro OpenAI Image API.
//  Bez vstupních obrázků → /v1/images/generations; se vstupy → /v1/images/edits (multipart).
//

import Foundation
import AppKit

struct OpenAIProvider: AIProvider {
    var kind: AIProviderKind { .chatgpt }
    var keychainAccount: String { "chatgpt" }

    func validate(apiKey: String) async -> Bool {
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return false }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    func generate(_ request: GenerationRequest, apiKey: String) async throws -> GenerationOutput {
        guard !apiKey.isEmpty else { throw ProviderError.missingKey }
        let data: Data
        if request.inputImages.isEmpty {
            data = try await generations(request, apiKey: apiKey)
        } else {
            data = try await edits(request, apiKey: apiKey)
        }
        return GenerationOutput(imageData: data, mimeType: "image/png", modelID: request.modelID)
            .cropped(to: request.inputImages.first?.pixelAspectRatio)
    }

    // MARK: text → image
    private func generations(_ request: GenerationRequest, apiKey: String) async throws -> Data {
        let body: [String: Any] = [
            "model": request.modelID,
            "prompt": request.prompt,
            "n": 1,
            "size": openAISize(for: request),
            "quality": "high",
        ]
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(req)
    }

    // MARK: image(+text) → image
    private func edits(_ request: GenerationRequest, apiKey: String) async throws -> Data {
        let boundary = "mulen-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        field("model", request.modelID)
        field("prompt", request.prompt)
        field("size", openAISize(for: request))
        field("quality", "high")
        for (i, image) in request.inputImages.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image[]\"; filename=\"img\(i).png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(image.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(image.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return try await send(req)
    }

    private func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "OpenAI API chyba"
            throw ProviderError.api(message)
        }
        guard let arr = json?["data"] as? [[String: Any]],
              let b64 = arr.first?["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64) else {
            throw ProviderError.noImageInResponse
        }
        return imageData
    }

    private func openAISize(for request: GenerationRequest) -> String {
        switch request.aspectRatio {
        case "9:16", "2:3", "3:4", "4:5":
            return "1024x1536"
        case "16:9", "3:2", "4:3", "5:4":
            return "1536x1024"
        case "Original":
            guard let image = request.inputImages.first,
                  let source = NSImage(data: image.data),
                  source.size.height > 0 else { return "1024x1024" }
            let ratio = source.size.width / source.size.height
            if ratio > 1.1 { return "1536x1024" }
            if ratio < 0.9 { return "1024x1536" }
            return "1024x1024"
        default:
            return "1024x1024"
        }
    }
}
