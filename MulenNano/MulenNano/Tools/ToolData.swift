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

    func fullPrompt(aspectRatio: String) -> String {
        [
            "You are performing a precise AI reframe / camera-angle variation from a single input image.",
            "",
            "Goal:",
            prompt,
            "",
            "Preservation rules:",
            "Keep the same primary subject, identity, objects, wardrobe/product design, architecture, environment, lighting direction, color temperature, lens realism, texture, and visual style.",
            "Change only the camera viewpoint, distance, crop, and visible composition required by the requested perspective.",
            "The selected perspective must be visibly different from the input camera angle. Make the requested camera change unmistakable.",
            "Do not restyle, beautify, replace the subject, change ethnicity, change product design, change room design, add text, add UI, add watermarks, or turn the image into a collage.",
            "If parts of the scene become visible because of the new angle, complete them plausibly from the original image context.",
            "",
            "Output aspect ratio: preserve the original input ratio (\(aspectRatio)).",
            "Return exactly one realistic full-frame image, with no labels, no grid, and no before/after layout.",
        ].joined(separator: "\n")
    }
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

enum BatchModelChoice: String, CaseIterable, Identifiable {
    case nanoPro
    case nano2
    case gptImage2

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nanoPro: "Nano Pro"
        case .nano2: "Nano 2"
        case .gptImage2: "GPT Img 2"
        }
    }

    var subtitle: String {
        switch self {
        case .nanoPro: "Gemini 3 Pro"
        case .nano2: "Gemini 3.1 Flash"
        case .gptImage2: "OpenAI"
        }
    }

    var provider: AIProviderKind {
        self == .gptImage2 ? .chatgpt : .gemini
    }

    var modelID: String {
        switch self {
        case .nanoPro: "gemini-3-pro-image"
        case .nano2: "gemini-3.1-flash-image"
        case .gptImage2: "gpt-image-2"
        }
    }
}

// MARK: - Face Swap prompt
enum FaceSwapMode: String, CaseIterable, Identifiable {
    case face = "Obličej", head = "Celá hlava"
    var id: String { rawValue }

    var title: String { self == .head ? "Head Swap" : "Face Swap" }

    var summary: String {
        self == .head
            ? "Přenese celou viditelnou hlavu včetně vlasové linie a uší."
            : "Přenese obličej a jen minimální okolí nutné pro přirozené napojení."
    }
}

enum FaceSwapPromptModel: String, CaseIterable, Identifiable {
    case gemini
    case openAI

    var id: String { rawValue }
    var provider: AIProviderKind { self == .gemini ? .gemini : .chatgpt }
    var modelID: String { self == .gemini ? "gemini-3-pro-image" : "gpt-image-2" }
    var title: String { self == .gemini ? "Gemini" : "GPT Img 2" }
}

enum FaceSwapModelChoice: String, CaseIterable, Identifiable {
    case gemini
    case openAI
    case both

    var id: String { rawValue }
    var title: String {
        switch self {
        case .gemini: "Gemini"
        case .openAI: "GPT Img 2"
        case .both: "Oba"
        }
    }
    var models: [FaceSwapPromptModel] {
        switch self {
        case .gemini: [.gemini]
        case .openAI: [.openAI]
        case .both: [.gemini, .openAI]
        }
    }
}

enum FaceSwapHairSource: String, CaseIterable, Identifiable {
    case target
    case source

    var id: String { rawValue }
    var title: String { self == .target ? "Cíl" : "Zdroj" }
}

enum FaceSwapGender: String, CaseIterable, Identifiable {
    case automatic
    case man
    case woman
    case nonbinary

    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "Auto"
        case .man: "Muž"
        case .woman: "Žena"
        case .nonbinary: "Nebinární"
        }
    }

    var promptValue: String? {
        switch self {
        case .automatic: nil
        case .man: "a man"
        case .woman: "a woman"
        case .nonbinary: "a nonbinary person"
        }
    }
}

enum FaceSwapPrompt {
    static func build(
        mode: FaceSwapMode,
        model: FaceSwapPromptModel,
        hairSource: FaceSwapHairSource,
        batchIndex: Int,
        gender: FaceSwapGender
    ) -> String {
        let scope = mode == .head
            ? "Replace the entire visible head of the person in the target image."
            : "Replace the visible face and only the minimum surrounding head area needed for a believable swap."
        let hairRule = hairSource == .source
            ? "Hair priority: preserve the source person hairline, hairstyle, color, density, baby hairs, sideburns, and ears whenever they are visible."
            : "Hair priority: preserve the target scene silhouette and edge integration only where needed, but keep the source identity dominant."
        let modelRule = model == .gemini
            ? "Optimize for a believable preview-quality edit with stable identity and minimal unintended repainting."
            : "Optimize for a polished final-quality edit with photorealistic blending and strong skin and eye detail, without changing identity."
        let variationRule: String
        switch batchIndex {
        case 0:
            variationRule = "Variation target: make the cleanest, safest, most identity-faithful version."
        case 1:
            variationRule = "Variation target: keep the same identity but try a slightly cleaner blend around hairline, ears, and neck seam."
        default:
            variationRule = "Variation target: keep the same identity but try a slightly stronger realism pass in texture, pores, and lighting coherence."
        }
        let genderRule = gender.promptValue.map {
            "Gender context: The source person is \($0). Ensure the result reads consistently as \($0)."
        }
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
            genderRule,
            hairRule,
            "",
            "Blend rule:",
            "Match the target body pose, neck connection, camera angle, lens perspective, lighting direction, color temperature, depth of field, grain, compression, and motion blur.",
            "",
            "Hard constraints:",
            "Do not invent a new face.",
            "Do not stylize, beautify, de-age, re-light the whole photo, smooth skin, or change ethnicity.",
            "Do not keep any facial features from the original target person.",
            "Do not alter body, hands, accessories, clothing, or background outside the minimum swap boundary.",
            "Do not output a split-screen, collage, before/after, contact sheet, diptych, inset, or any second image.",
            "Do not reproduce the reference inset in the final output.",
            "",
            modelRule,
            variationRule,
            "",
            "Output requirement:",
            "Return one single full-frame realistic swapped photo of the target scene only, with no layout elements or reference panels visible.",
        ].compactMap { $0 }.joined(separator: "\n")
    }
}

// MARK: - Upscaler prompt
enum UpscalePrompt {
    static let prompt = "Upscale this image to higher resolution and enhance fine detail, sharpness, and texture. Preserve the original subject, composition, colors, lighting, and content exactly. Do not add, remove, or restyle anything — only increase clarity and resolution naturally, without AI artifacts or over-sharpening."
}

enum UpscaleBranch: String, CaseIterable, Identifiable {
    case faithful
    case creative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .faithful: "Faithful"
        case .creative: "Creative"
        }
    }

    var summary: String {
        switch self {
        case .faithful:
            "Věrné zvětšení bez agresivního přemýšlení detailů."
        case .creative:
            "Detail reconstruction blíž Magnific-style upscale."
        }
    }
}

private enum UpscalePrompts {
    static let detailEnhance = "Upscale this image and intelligently enhance real visible detail only. Improve sharpness, fine texture clarity, edge definition, material detail, and local contrast while preserving the original image faithfully. Do not redesign, repaint, stylize, beautify, relight creatively, add new objects, alter identity, change composition, change colors, or invent details that are not plausibly supported by the source. The result must look like a high-quality technical restoration and detail enhancement, not an AI reinterpretation."
    static let faithful = "Upscale this image faithfully without any creative intent. Preserve the original photo as much as possible, only compute necessary artifacts."
    static let denoise = "Remove noise, grain, compression artifacts, and sensor noise from this image. Make it clean and crisp. Preserve all original details, colors, and subject identity. Do not add creative changes."
    static let upscaleOnly = "Increase the resolution of this image without any AI enhancement, artistic interpretation, or modification. Pure geometric upscaling only. Preserve exact pixel content, colors, and detail as-is."
}

enum UpscaleMode: String, CaseIterable, Identifiable {
    case detailEnhance = "detail-enhance"
    case restore
    case enhance
    case denoise
    case upscaleOnly = "upscale-only"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .detailEnhance: "Detail Enhance"
        case .restore: "Restore"
        case .enhance: "Enhance"
        case .denoise: "Denoise"
        case .upscaleOnly: "Upscale Only"
        }
    }

    var summary: String {
        switch self {
        case .detailEnhance: "Upscale + detail bez kreativity"
        case .restore: "Opraví artefakty, zachová detail"
        case .enhance: "AI vylepšení, více kreativity"
        case .denoise: "Odstraní šum a grain"
        case .upscaleOnly: "Čisté zvětšení bez AI zásahu"
        }
    }

    var prompt: String {
        switch self {
        case .detailEnhance: UpscalePrompts.detailEnhance
        case .restore, .enhance: UpscalePrompts.faithful
        case .denoise: UpscalePrompts.denoise
        case .upscaleOnly: UpscalePrompts.upscaleOnly
        }
    }
}

enum UpscaleModelChoice: String, CaseIterable, Identifiable {
    case nanoPro
    case nano2

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nanoPro: "Nano Pro"
        case .nano2: "Nano 2"
        }
    }

    var subtitle: String {
        switch self {
        case .nanoPro: "Gemini 3 Pro"
        case .nano2: "Gemini 3.1 Flash"
        }
    }

    var modelID: String {
        switch self {
        case .nanoPro: "gemini-3-pro-image"
        case .nano2: "gemini-3.1-flash-image"
        }
    }
}

enum UpscaleScale: Int, CaseIterable, Identifiable {
    case x2 = 2
    case x4 = 4

    var id: Int { rawValue }

    var title: String { "\(rawValue)\u{00D7}" }

    var geminiResolution: String {
        switch self {
        case .x2: "1K"
        case .x4: "2K"
        }
    }
}

enum CreativeUpscalePreset: String, CaseIterable, Identifiable {
    case natural
    case balanced
    case bold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural: "Natural"
        case .balanced: "Balanced"
        case .bold: "Bold"
        }
    }

    var summary: String {
        switch self {
        case .natural: "Drží se předlohy, jen vrací detail."
        case .balanced: "Vyvážený creative upscale pro většinu fotek."
        case .bold: "Silnější textury a odvážnější rekonstrukce detailu."
        }
    }

    var prompt: String {
        switch self {
        case .natural:
            "ultra detailed, high resolution, realistic, preserve identity, preserve material texture, clean edges, natural skin texture, true-to-source detail"
        case .balanced:
            "ultra detailed, premium high resolution, refined textures, realistic facial detail, rich material definition, crisp but natural finish"
        case .bold:
            "ultra detailed, cinematic high resolution, intense texture recovery, strong fine detail, dramatic clarity, luxurious surface definition"
        }
    }

    var creativity: Double {
        switch self {
        case .natural: 0.22
        case .balanced: 0.38
        case .bold: 0.62
        }
    }

    var resemblance: Double {
        switch self {
        case .natural: 1.25
        case .balanced: 0.9
        case .bold: 0.58
        }
    }

    var dynamic: Double {
        switch self {
        case .natural: 4
        case .balanced: 6
        case .bold: 8
        }
    }

    var sharpen: Double {
        switch self {
        case .natural: 1
        case .balanced: 2
        case .bold: 3
        }
    }
}
