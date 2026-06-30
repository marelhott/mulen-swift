//
//  GenerateModel.swift
//  MulenNano
//
//  Stav generovacího pohledu. Zatím čistě lokální (bez napojení na AI).
//

import SwiftUI
import Observation

enum AspectRatioOption: String, CaseIterable, Identifiable {
    case original = "Original"
    case square = "1:1"
    case portrait = "2:3"
    case landscape = "3:2"
    case photoPortrait = "4:5"
    case photoLandscape = "5:4"
    case classicLandscape = "4:3"
    case classicPortrait = "3:4"
    case tall = "9:16"
    case wide = "16:9"

    var id: String { rawValue }
    var summary: String {
        switch self {
        case .original:
            "Zachová původní poměr bez vynucení nového formátu."
        case .square:
            "Univerzální čtverec vhodný pro produkt, avatar i feed."
        case .portrait:
            "Vyšší portrét pro postavu, módu a mobilní kompozice."
        case .landscape:
            "Širší záběr pro scénu, interiér a horizontální kompozici."
        case .photoPortrait:
            "Fotografický portrét vhodný pro lifestyle a editorial."
        case .photoLandscape:
            "Fotografická krajina pro produkt v prostoru a širší scénu."
        case .classicLandscape:
            "Klasický horizontální formát blízký běžné fotografii."
        case .classicPortrait:
            "Klasický vertikální formát s přirozeným fotografickým dojmem."
        case .tall:
            "Vysoký mobilní formát pro stories, reels a plakátové kompozice."
        case .wide:
            "Široký filmový formát pro bannery, scénu a výrazný horizont."
        }
    }
}

enum ResolutionOption: String, CaseIterable, Identifiable {
    case oneK = "1K"
    case twoK = "2K"
    case fourK = "4K"

    var id: String { rawValue }
    var summary: String {
        switch self {
        case .oneK:
            "Rychlý základní výstup pro běžné použití a iterace."
        case .twoK:
            "Vyšší detail pro kvalitnější náhled a jemnější textury."
        case .fourK:
            "Nejvyšší cílová kvalita pro maximální detail, pokud ji model opravdu vrátí."
        }
    }
}

enum PromptMode: String, CaseIterable, Identifiable {
    case simple = "Simple"
    case interpretace = "Interpretace"
    var id: String { rawValue }
}

enum AdvancedVariant: String, CaseIterable, Identifiable {
    case a = "A", b = "B", c = "C"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .a: "Autenticita"
        case .b: "Vylepšení"
        case .c: "Vyvážené"
        }
    }
    var tooltip: String {
        switch self {
        case .a: "Maximální autenticita — přirozené, nedokonalé, věrohodné."
        case .b: "Maximální vylepšení — vybroušené, filmové, prémiové."
        case .c: "Vyvážený realismus — neutrální výchozí."
        }
    }
}

/// Režim při více referenčních obrázcích.
enum MultiRefMode: String, CaseIterable, Identifiable {
    case together = "Sloučit"
    case batch = "Varianty"
    var id: String { rawValue }
    var summary: String {
        switch self {
        case .together:
            "Použije všechny vstupy naráz a spojí je do jednoho výsledku."
        case .batch:
            "Pracuje s referencemi po variantách a zkouší různé kombinace."
        }
    }
}

/// Režimy promptu v simple módu (původní „Styl / Merge / Object").
enum SimpleLinkMode: String, CaseIterable, Identifiable {
    case styl, merge, object
    var id: String { rawValue }
    var label: String {
        switch self {
        case .styl: "Styl"
        case .merge: "Merge"
        case .object: "Object"
        }
    }
    var summary: String {
        switch self {
        case .styl:
            "Přenese vzhled a atmosféru stylových referencí, ale zachová obsah zadání."
        case .merge:
            "Spojí obsah vstupních obrázků do jedné přirozené a soudržné scény."
        case .object:
            "Použije referenci jako konkrétní objekt nebo produkt a zachová jeho podobu."
        }
    }
    /// Klíč shodný s webem (style/merge/object) pro [LINK MODE] hlavičku.
    var linkKey: String {
        switch self {
        case .styl: "style"
        case .merge: "merge"
        case .object: "object"
        }
    }
}

/// AI poskytovatel (provider). V1: Gemini + ChatGPT, připraveno na další.
enum AIProviderKind: String, CaseIterable, Identifiable {
    case gemini = "Gemini"
    case chatgpt = "ChatGPT"
    case replicate = "Replicate"
    var id: String { rawValue }
}

/// Modelový preset — ekvivalent „Výběr modelů" z pravého panelu.
struct ModelPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let provider: AIProviderKind
    let modelID: String
    let enabled: Bool

    static let all: [ModelPreset] = [
        ModelPreset(id: "nano-pro", title: "Nano Pro",  subtitle: "Gemini 3 Pro",     provider: .gemini,  modelID: "gemini-3-pro-image",     enabled: true),
        ModelPreset(id: "nano-2",   title: "Nano 2",    subtitle: "Gemini 3.1 Flash", provider: .gemini,  modelID: "gemini-3.1-flash-image", enabled: true),
        ModelPreset(id: "gpt-img",  title: "GPT Img 2", subtitle: "OpenAI · pomalý",  provider: .chatgpt, modelID: "gpt-image-2",                    enabled: true),
        ModelPreset(id: "flux-pro", title: "Flux Pro",  subtitle: "Fal AI · brzy",    provider: .gemini,  modelID: "",                               enabled: false),
    ]
}

@Observable
final class GenerateModel {
    // Prompt
    var prompt: String = ""
    var mode: PromptMode = .simple
    var variant: AdvancedVariant = .c
    var faceIdentity: Bool = false
    var simpleLinkMode: SimpleLinkMode? = nil

    // Výstup
    var count: Int = 1
    var aspectRatio: AspectRatioOption = .original
    var resolution: ResolutionOption = .oneK

    // Vstupy
    var sourceImages: [URL] = []
    var styleImages: [URL] = []
    var assetImages: [URL] = []
    var multiRefMode: MultiRefMode = .together
    var styleStrength: Double = 60

    // Engine
    var modelPresetID: String = "nano-pro"
    var provider: AIProviderKind = .gemini

    var selectedPreset: ModelPreset? {
        ModelPreset.all.first { $0.id == modelPresetID }
    }

    func selectPreset(_ preset: ModelPreset) {
        guard preset.enabled else { return }
        modelPresetID = preset.id
        provider = preset.provider
    }

    var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !sourceImages.isEmpty
    }
}
