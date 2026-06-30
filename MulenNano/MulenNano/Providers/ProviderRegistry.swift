//
//  ProviderRegistry.swift
//  MulenNano
//
//  Registr providerů — přidání nového = jediný řádek zde.
//  Drží i přístup k API klíčům (přes Keychain).
//

import Foundation
import Observation

@Observable
final class ProviderRegistry {
    /// Registr — přidat providera = přidat jeden řádek.
    private let providers: [AIProviderKind: AIProvider] = [
        .gemini: GeminiProvider(),
        .chatgpt: OpenAIProvider(),
        .replicate: ReplicateProvider(),
    ]

    /// Zrcadlo přítomnosti klíčů pro UI (aby se View překreslilo po uložení).
    var keyPresence: [AIProviderKind: Bool] = [:]

    init() {
        refreshKeyPresence()
    }

    func provider(for kind: AIProviderKind) -> AIProvider? {
        providers[kind]
    }

    func isImplemented(_ kind: AIProviderKind) -> Bool {
        providers[kind] != nil
    }

    // MARK: Klíče
    func apiKey(for kind: AIProviderKind) -> String? {
        Keychain.get(kind.keychainAccount)
    }

    func setAPIKey(_ value: String, for kind: AIProviderKind) throws {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        try Keychain.set(normalized, for: kind.keychainAccount)
        refreshKeyPresence()
    }

    func deleteAPIKey(for kind: AIProviderKind) throws {
        try Keychain.delete(kind.keychainAccount)
        refreshKeyPresence()
    }

    func hasKey(for kind: AIProviderKind) -> Bool {
        keyPresence[kind] ?? false
    }

    private func refreshKeyPresence() {
        var map: [AIProviderKind: Bool] = [:]
        for kind in AIProviderKind.allCases {
            map[kind] = !(Keychain.get(kind.keychainAccount) ?? "").isEmpty
        }
        keyPresence = map
    }
}

extension AIProviderKind {
    var keychainAccount: String {
        switch self {
        case .gemini:  "gemini"
        case .chatgpt: "chatgpt"
        case .replicate: "replicate"
        }
    }
}
