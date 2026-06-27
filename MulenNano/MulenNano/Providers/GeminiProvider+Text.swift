//
//  GeminiProvider+Text.swift
//  MulenNano
//
//  Textové operace Gemini — vylepšení promptu a generování 3 variant (1:1 z geminiService.ts).
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

    func promptVariants(_ prompt: String, apiKey: String) async throws -> [PromptVariant] {
        guard !apiKey.isEmpty else { throw ProviderError.missingKey }
        let instruction = """
        Jsi expert na vytváření variant promptů pro AI generování obrázů.

        ÚKOL: Vezmi základní prompt a vytvoř 3 VARIACE s různými přístupy.

        ## KRITICKÉ PRAVIDLO
        ✓ Všechny 3 varianty musí vycházet ze STEJNÉHO základního tématu
        ✓ Každá varianta mění PERSPEKTIVU, NÁLADU nebo DETAIL
        ✓ Změny musí být MALÉ ale znatelné
        ✓ Zachovej původní záměr

        ## FORMÁT VÝSTUPU
        [
          {"variant": "Variace 1", "approach": "popis změny", "prompt": "..."},
          {"variant": "Variace 2", "approach": "popis změny", "prompt": "..."},
          {"variant": "Variace 3", "approach": "popis změny", "prompt": "..."}
        ]

        Uživatelův prompt: "\(prompt)"

        VYPIŠ POUZE JSON POLE:
        """
        var text = try await callText(instruction, apiKey: apiKey, temperature: 0.7, maxTokens: 4096)
        text = text.replacingOccurrences(of: "```json", with: "")
                   .replacingOccurrences(of: "```", with: "")
                   .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = text.data(using: .utf8),
              let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            throw ProviderError.api("Nepodařilo se načíst varianty promptu.")
        }
        return arr.compactMap { dict in
            guard let p = dict["prompt"] as? String else { return nil }
            return PromptVariant(
                variant: (dict["variant"] as? String) ?? "Varianta",
                approach: (dict["approach"] as? String) ?? "",
                prompt: p
            )
        }
    }
}
