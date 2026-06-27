//
//  PromptStores.swift
//  MulenNano
//
//  Uložené prompty (perzistence v UserDefaults) + výchozí šablony (1:1 z webu).
//

import SwiftUI
import Observation

// MARK: - Uložené prompty
struct SavedPrompt: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var prompt: String
    var createdAt: Date = Date()
}

@Observable
final class SavedPromptStore {
    private let key = "mulen.savedPrompts"
    private(set) var prompts: [SavedPrompt] = []

    init() { load() }

    func add(name: String, prompt: String) {
        prompts.insert(SavedPrompt(name: name, prompt: prompt), at: 0)
        save()
    }

    func delete(_ id: UUID) {
        prompts.removeAll { $0.id == id }
        save()
    }

    func update(_ id: UUID, name: String, prompt: String) {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[index].name = name
        prompts[index].prompt = prompt
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedPrompt].self, from: data) else { return }
        prompts = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(prompts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Šablony promptů (výchozí dle webu)
struct PromptTemplate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let template: String       // proměnné jako [SUBJECT]
    let variables: [String]
    let category: String

    static let defaults: [PromptTemplate] = [
        .init(name: "Základní scéna", template: "[SUBJECT] v [STYLE] stylu, [TIME_OF_DAY] osvětlení",
              variables: ["SUBJECT", "STYLE", "TIME_OF_DAY"], category: "Obecné"),
        .init(name: "Portrét", template: "Portrét [PERSON], [EMOTION] výraz, [BACKGROUND] pozadí, [LIGHTING] světlo",
              variables: ["PERSON", "EMOTION", "BACKGROUND", "LIGHTING"], category: "Portréty"),
        .init(name: "Krajina", template: "[LOCATION] krajina, [SEASON] sezóna, [WEATHER] počasí, [ATMOSPHERE] atmosféra",
              variables: ["LOCATION", "SEASON", "WEATHER", "ATMOSPHERE"], category: "Krajiny"),
        .init(name: "Produkt", template: "[PRODUCT] na [SURFACE], [ANGLE] úhel, [LIGHTING] osvětlení, [MOOD] nálada",
              variables: ["PRODUCT", "SURFACE", "ANGLE", "LIGHTING", "MOOD"], category: "Produkty"),
        .init(name: "Interiér", template: "[ROOM_TYPE] místnost, [DESIGN_STYLE] styl, [COLOR_SCHEME] barevné schéma, [FURNITURE] nábytek",
              variables: ["ROOM_TYPE", "DESIGN_STYLE", "COLOR_SCHEME", "FURNITURE"], category: "Interiéry"),
        .init(name: "Umělecké dílo", template: "[ART_STYLE] umění zobrazující [SUBJECT], [TECHNIQUE] technika, [COLOR_PALETTE] paleta",
              variables: ["ART_STYLE", "SUBJECT", "TECHNIQUE", "COLOR_PALETTE"], category: "Umění"),
    ]

    func fill(_ values: [String: String]) -> String {
        var result = template
        for v in variables {
            let replacement = values[v]?.isEmpty == false ? values[v]! : v.lowercased()
            result = result.replacingOccurrences(of: "[\(v)]", with: replacement)
        }
        return result
    }
}
