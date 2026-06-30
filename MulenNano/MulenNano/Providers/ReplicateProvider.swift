//
//  ReplicateProvider.swift
//  MulenNano
//
//  Creative upscale provider přes Replicate predictions API.
//

import Foundation
import OSLog

struct ReplicateProvider: AIProvider {
    var kind: AIProviderKind { .replicate }
    var keychainAccount: String { "replicate" }

    static let clarityModelID = "philz1337x/clarity-upscaler"

    private static let logger = Logger(subsystem: "com.mulen.MulenNano", category: "ReplicateProvider")
    private static let baseURL = URL(string: "https://api.replicate.com/v1")!
    private static let clarityVersion = "dfad41707589d68ecdccd1dfa600d55a208f9310748e44bfe35b4a6291453d5e"

    func validate(apiKey: String) async -> Bool {
        guard !apiKey.isEmpty else { return false }
        var request = URLRequest(url: Self.baseURL.appending(path: "models"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func generate(_ request: GenerationRequest, apiKey: String) async throws -> GenerationOutput {
        guard !apiKey.isEmpty else { throw ProviderError.missingKey }
        guard let image = request.inputImages.first else {
            throw ProviderError.api("Creative upscale vyžaduje vstupní obrázek.")
        }

        let version = versionID(for: request.modelID)
        let input = buildInput(request: request, image: image)
        let prediction = try await createPrediction(version: version, input: input, apiKey: apiKey)
        let finalPrediction = try await pollPrediction(id: prediction.id, apiKey: apiKey)

        guard finalPrediction.status == "succeeded" else {
            throw ProviderError.api(finalPrediction.error ?? "Creative upscale selhal.")
        }

        guard let outputURL = finalPrediction.firstOutputURL else {
            throw ProviderError.noImageInResponse
        }

        let (data, response) = try await URLSession.shared.data(from: outputURL)
        let mimeType = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type")?
            .components(separatedBy: ";")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "image/png"

        Self.logger.info("Replicate output downloaded bytes=\(data.count)")
        return GenerationOutput(imageData: data, mimeType: mimeType, modelID: request.modelID)
    }

    private func buildInput(request: GenerationRequest, image: InputImage) -> [String: Any] {
        var input: [String: Any] = [
            "image": dataURL(for: image),
            "output_format": "png",
        ]

        if !request.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            input["prompt"] = request.prompt
        }

        for (key, value) in request.providerOptions {
            input[key] = value.jsonValue
        }

        return input
    }

    private func versionID(for modelID: String) -> String {
        switch modelID {
        case Self.clarityModelID:
            Self.clarityVersion
        default:
            Self.clarityVersion
        }
    }

    private func createPrediction(
        version: String,
        input: [String: Any],
        apiKey: String
    ) async throws -> ReplicatePrediction {
        var request = URLRequest(url: Self.baseURL.appending(path: "predictions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "version": version,
            "input": input,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodePrediction(data: data, response: response, fallbackMessage: "Replicate request selhal")
    }

    private func pollPrediction(id: String, apiKey: String) async throws -> ReplicatePrediction {
        let timeout: TimeInterval = 300
        let start = Date()
        var delay: UInt64 = 1_200_000_000

        while true {
            if Date().timeIntervalSince(start) > timeout {
                throw ProviderError.api("Creative upscale trvá příliš dlouho. Zkus to prosím znovu.")
            }

            try await Task.sleep(nanoseconds: delay)
            delay = min(UInt64(Double(delay) * 1.35), 8_000_000_000)

            var request = URLRequest(url: Self.baseURL.appending(path: "predictions/\(id)"))
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)
            let prediction = try decodePrediction(data: data, response: response, fallbackMessage: "Replicate polling selhal")
            switch prediction.status {
            case "starting", "processing":
                continue
            default:
                return prediction
            }
        }
    }

    private func decodePrediction(
        data: Data,
        response: URLResponse,
        fallbackMessage: String
    ) throws -> ReplicatePrediction {
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.api("Žádná odpověď serveru.")
        }
        if !(200..<300).contains(http.statusCode) {
            let errorMessage = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let detail = (errorMessage?["detail"] as? String)
                ?? (errorMessage?["error"] as? String)
                ?? fallbackMessage
            throw ProviderError.api("\(detail) (\(http.statusCode))")
        }

        let decoder = JSONDecoder()
        let prediction = try decoder.decode(ReplicatePrediction.self, from: data)
        guard 200..<300 ~= http.statusCode else {
            throw ProviderError.api(prediction.error ?? "\(fallbackMessage) (\(http.statusCode))")
        }
        return prediction
    }

    private func dataURL(for image: InputImage) -> String {
        "data:\(image.mimeType);base64,\(image.data.base64EncodedString())"
    }
}

private struct ReplicatePrediction: Decodable {
    let id: String
    let status: String
    let output: ReplicateOutput?
    let error: String?

    var firstOutputURL: URL? {
        switch output {
        case .single(let value):
            return URL(string: value)
        case .multiple(let values):
            return values.compactMap(URL.init(string:)).first
        case .none:
            return nil
        }
    }
}

private enum ReplicateOutput: Decodable {
    case single(String)
    case multiple([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            self = .single(single)
            return
        }
        if let multiple = try? container.decode([String].self) {
            self = .multiple(multiple)
            return
        }
        throw DecodingError.typeMismatch(
            ReplicateOutput.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported Replicate output payload")
        )
    }
}
