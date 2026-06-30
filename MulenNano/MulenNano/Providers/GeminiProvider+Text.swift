//
//  GeminiProvider+Text.swift
//  MulenNano
//
//  Textové operace Gemini pro vylepšení promptu.
//

import Foundation

extension GeminiProvider {
    private static let textModel = "gemini-3-flash-preview"

    private func textEndpoint(apiKey: String) -> URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(Self.textModel):generateContent?key=\(apiKey)")!
    }

    private func callText(_ instruction: String, apiKey: String, temperature: Double, maxTokens: Int) async throws -> String {
        let body: [String: Any] = [
            "contents": [["parts": [["text": instruction]]]],
            "generationConfig": ["temperature": temperature, "maxOutputTokens": maxTokens],
        ]
        var req = URLRequest(url: textEndpoint(apiKey: apiKey))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "Gemini text API chyba"
            throw ProviderError.api(message)
        }
        let candidates = json?["candidates"] as? [[String: Any]] ?? []
        let parts = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        return parts.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func enhancePrompt(_ prompt: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw ProviderError.missingKey }
        let instruction = """
        Jsi profesionální prompt engineer. Vezmi následující krátký prompt pro generování obrázků a rozšiř ho do detailního, živého popisu, který vytvoří lepší AI-generované obrázky.

        Přidej konkrétní detaily o:
        - Vizuálním stylu a estetice
        - Osvětlení a atmosféře
        - Barvách a texturách
        - Kompozici a perspektivě
        - Deskriptorech kvality (vysoce detailní, profesionální, atd.)

        Zachovej hlavní nápad, ale udělej ho popisnějším a konkrétnějším. Vrať POUZE vylepšený prompt v češtině, nic jiného.

        Krátký prompt: "\(prompt)"

        Vylepšený prompt:
        """
        let result = try await callText(instruction, apiKey: apiKey, temperature: 0.7, maxTokens: 2048)
        return result.isEmpty ? prompt : result
    }

}
