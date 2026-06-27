//
//  ToolData.swift
//  MulenNano
//
//  Presety a prompty nástrojů (1:1 z webu: Reframe, Batch, Face Swap).
//

import Foundation

// MARK: - Reframe perspektivy
struct ReframePerspective: Identifiable, Hashable {
    let id: String
    let label: String
    let prompt: String

    static let all: [ReframePerspective] = [
        .init(id: "ext-long-shot", label: "Ext. long shot", prompt: "Reframe as an extreme long shot. Pull the camera far back and reveal more environment around the same subject while preserving identity, architecture, lighting, materials, palette, and scene logic."),
        .init(id: "long-shot", label: "Long shot", prompt: "Reframe as a long shot. Show the full subject and surrounding scene with a natural wider camera position, while keeping the original place, objects, subject identity, lighting, and style intact."),
        .init(id: "closeup", label: "Closeup", prompt: "Reframe as a closeup. Move the camera closer to the main subject and crop tighter, preserving the original identity, materials, colors, lighting direction, and photographic realism."),
        .init(id: "medium-long", label: "Medium long", prompt: "Reframe as a medium long shot. Keep the subject readable in context, between a full-body/scene view and a medium framing, preserving all core visual details from the input image."),
        .init(id: "extreme-closeup", label: "Extreme closeup", prompt: "Reframe as an extreme closeup of the most important subject detail. Preserve texture, identity, material fidelity, lighting, color, and scene consistency without inventing a different object or person."),
        .init(id: "low-angle", label: "Low angle", prompt: "Reframe from a low camera angle looking upward. Keep the same subject, location, clothing or object design, lighting, color temperature, and realistic perspective."),
        .init(id: "back-view", label: "Back view", prompt: "Reframe as a believable back view of the same scene and subject. Preserve clothing, body proportions, hairstyle or object structure, materials, environment, lighting, and spatial layout."),
        .init(id: "medium-closeup", label: "Med. closeup", prompt: "Reframe as a medium closeup. Keep the main subject dominant but include enough surrounding context to match the original scene, lighting, color, and perspective."),
        .init(id: "high-angle", label: "High angle", prompt: "Reframe from a high camera angle looking down. Preserve the original subject, scene geometry, materials, identity, lighting direction, and photographic style."),
        .init(id: "ots", label: "OTS", prompt: "Reframe as an over-the-shoulder shot where the viewer sees past the nearest subject or foreground element toward the main subject, preserving the original scene and identity."),
        .init(id: "wide", label: "Wide", prompt: "Reframe as a wide cinematic shot with more horizontal environment visible. Preserve the main subject, location, lighting, lens feel, and photographic realism."),
        .init(id: "aerial", label: "Aerial", prompt: "Reframe as an aerial or top-down camera view where plausible. Preserve scene layout, object identity, architecture, lighting, colors, and materials."),
        .init(id: "profile", label: "Profile", prompt: "Reframe as a strict side profile view of the same subject, with the camera rotated about 90 degrees from the original front/three-quarter view. The face, body, or main object must be seen from the side silhouette. Do not return a front-facing or near-front crop."),
        .init(id: "pov", label: "POV", prompt: "Reframe as a first-person point-of-view shot from inside the same scene. The camera must feel like the viewer is physically present, with plausible foreground hints such as hands, knees, table edge, cup, phone, doorway, or body-level framing when appropriate. Do not return a normal portrait crop."),
    ]
}

// MARK: - Batch presety
struct BatchPreset: Identifiable, Hashable {
    let id: String
    let label: String
    let title: String
    let prompt: String

    static let all: [BatchPreset] = [
        .init(id: "general", label: "Obecný", title: "Obecné vylepšení",
              prompt: "Vylepši tuto fotografii obecně. Srovnej její osvětlení, jemně oprav barvy a kontrast, proveď kvalitní upscaling, odstraň rušivé prvky a drobné nedostatky, ale plně zachovej původní scénu, kompozici, materiály i atmosféru. Výsledek musí působit přirozeně, věrohodně a profesionálně, bez AI artefaktů, bez přehnané stylizace a bez umělého přepracování."),
        .init(id: "portrait", label: "Portrét", title: "Portrétní vylepšení",
              prompt: "Vylepši tento portrét velmi přirozeně a citlivě. Zachovej identitu člověka, proporce obličeje, texturu pleti, vlasy i výraz. Jemně srovnej světlo, tón pleti, kontrast a ostrost, proveď kvalitní upscaling a odstraň rušivé drobnosti. Výsledek musí působit jako špičkově nafocený portrét, ne jako přemalovaný nebo plastický AI obraz."),
        .init(id: "interior", label: "Interiér", title: "Interiérové zasazení",
              prompt: "Vylepši tento vstup pro interiérovou prezentaci. Barevně i světelně jej zharmonizuj, proveď čistý upscaling a zachovej materiály, strukturu a charakter předlohy. Pokud je vstup detail dekorativní stěny, povrchu nebo prvku, velmi logicky a přirozeně jej rozviň do uvěřitelného interiéru, kde tento prvek dává smysl. Výsledek musí být elegantní, realistický, prostorově přesvědčivý a bez AI slopu nebo laciné stylizace."),
    ]

    static func buildPrompt(_ preset: BatchPreset, custom: String) -> String {
        let extra = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        return extra.isEmpty ? preset.prompt : "\(preset.prompt)\n\nDodatečné instrukce: \(extra)"
    }
}

// MARK: - Face Swap prompt
enum FaceSwapMode: String, CaseIterable, Identifiable {
    case face = "Obličej", head = "Celá hlava"
    var id: String { rawValue }
}

enum FaceSwapPrompt {
    static func build(mode: FaceSwapMode) -> String {
        let scope = mode == .head
            ? "Replace the entire visible head of the person in the target image."
            : "Replace the visible face and only the minimum surrounding head area needed for a believable swap."
        return [
            "You are performing a precise identity-preserving face/head swap from a target-first reference composite.",
            "",
            "Composite input layout:",
            "Main large image = target image. Keep its body, pose, clothing, framing, background, composition, and scene intact.",
            "Small top-right inset = source identity. Use this inset as the only identity source for the swap.",
            "",
            scope,
            "",
            "Identity lock:",
            "Preserve the source identity exactly: facial geometry, skull shape, forehead, hairline, hairstyle, eyebrows, eyes, nose, cheeks, lips, jawline, chin, ears, skin tone, texture, age cues, facial hair, and likeness.",
            "Hair priority: preserve the source person hairline, hairstyle, color, density, baby hairs, sideburns, and ears whenever they are visible.",
            "Optimize for a believable edit with stable identity and minimal unintended repainting.",
            "Return only the final edited target image, with no inset and no extra framing.",
        ].joined(separator: "\n")
    }
}

// MARK: - Upscaler prompt
enum UpscalePrompt {
    static let prompt = "Upscale this image to higher resolution and enhance fine detail, sharpness, and texture. Preserve the original subject, composition, colors, lighting, and content exactly. Do not add, remove, or restyle anything — only increase clarity and resolution naturally, without AI artifacts or over-sharpening."
}
