//
//  PromptComposition.swift
//  MulenNano
//
//  Přesný port skládání promptů z webové Mulen nano:
//  utils/promptComposition.ts, promptInterpretation.ts, styleStrength.ts.
//  Instrukce pro AI jsou anglické záměrně (1:1 s originálem).
//

import Foundation

enum PromptComposition {

    // MARK: - Simple link mode (Styl / Merge / Object)
    static func buildSimpleLinkPrompt(
        mode: SimpleLinkMode,
        extra: String,
        referenceImageCount: Int,
        styleImageCount: Int,
        assetImageCount: Int
    ) -> String {
        let header = """

        [LINK MODE: \(mode.linkKey.uppercased())]
        Images order: first \(referenceImageCount) input image(s), then \(styleImageCount) style image(s), then \(assetImageCount) proprietary asset image(s).

        """
        let additional = extra.isEmpty ? "" : "Additional instructions:\n\(extra)\n"

        switch mode {
        case .styl:
            return """
            \(header)
            Apply the visual style, composition, lighting, color grading, lens feel, and overall mood from the style image(s) to the input image(s), while preserving the identity and content of the input subject(s). Do NOT transfer objects/content from style; transfer only aesthetic and photographic/artistic treatment.

            \(additional)
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        case .merge:
            return """
            \(header)
            Create a cohesive merge of input and style images. You may blend both aesthetic and content elements to produce a unified result that feels intentional, natural, and high quality. Use the style image(s) as a compositional template when helpful, but preserve the identity of subjects from the input image(s).

            \(additional)
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        case .object:
            return """
            \(header)
            Transfer the dominant object/element from the style image(s) onto the input image(s) in a realistic way. Keep the input scene intact and place/replace the matching region with the style object (e.g., decorative wall), with correct perspective, lighting, scale, and shadows.

            \(additional)
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Advanced interpretation (varianty A/B/C + identita tváře)
    static func applyAdvancedInterpretation(
        _ userPrompt: String,
        variant: AdvancedVariant,
        faceIdentityMode: Bool
    ) -> String {
        var parts: [String] = [userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)]
        parts.append("\n\n[INTERPRETATION INSTRUCTION - VARIANT \(variant.rawValue)]")
        parts.append(variantInstruction(variant))
        if faceIdentityMode {
            parts.append("\n\n[OVERRIDE - FACE IDENTITY PRESERVATION]")
            parts.append(faceIdentityInstruction)
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Style strength
    static func styleQualifier(_ strength: Int) -> String {
        switch strength {
        case ...10: "with only the faintest, barely noticeable hint of"
        case ...25: "with a subtle, gentle influence of"
        case ...40: "lightly inspired by"
        case ...60: "in the style of"
        case ...75: "strongly adopting the style of"
        case ...90: "heavily transformed into the style of"
        default:    "completely reimagined in the exact style of"
        }
    }

    static func buildStyleStrengthInstruction(_ strength: Int) -> String {
        let qualifier = styleQualifier(strength)
        let tail = strength < 30
            ? "Keep the original content mostly intact."
            : strength > 70
                ? "Let the style dominate the output."
                : "Balance style with content."
        return "[STYLE STRENGTH: \(strength)%] Apply the style reference \(qualifier) the provided style image(s). \(tail)"
    }

    // MARK: - Orchestrátor (composeGenerationPrompt)
    struct Input {
        var prompt: String
        var advanced: Bool
        var advancedVariant: AdvancedVariant
        var faceIdentityMode: Bool
        var simpleLinkMode: SimpleLinkMode?
        var sourceImageCount: Int
        var styleImageCount: Int
        var assetImageCount: Int
        var multiRefBatch: Bool          // true = 'batch', false = 'together'
        var styleStrength: Int
        var sourcePrompt: String?
    }

    /// Vrací (basePrompt, enhancedPrompt) — enhancedPrompt jde do modelu.
    static func compose(_ input: Input) -> (base: String, enhanced: String) {
        var extraPrompt = input.prompt
        if extraPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let source = input.sourcePrompt {
            extraPrompt = source
        }

        var basePrompt: String
        if !input.advanced, let mode = input.simpleLinkMode {
            basePrompt = buildSimpleLinkPrompt(
                mode: mode,
                extra: extraPrompt,
                referenceImageCount: input.sourceImageCount,
                styleImageCount: input.styleImageCount,
                assetImageCount: input.assetImageCount
            )
        } else {
            basePrompt = extraPrompt
        }

        if input.advanced {
            basePrompt = applyAdvancedInterpretation(basePrompt, variant: input.advancedVariant, faceIdentityMode: input.faceIdentityMode)
        } else if input.faceIdentityMode {
            basePrompt = applyAdvancedInterpretation(basePrompt, variant: .c, faceIdentityMode: true)
            basePrompt += "\n\n[VARIATION REQUIREMENT: Create a unique and visually distinct interpretation. Vary pose, angle, clothing, environment, lighting, mood, and context significantly. Make each image tell a different story while keeping the same recognizable face.]"
        }

        var enhanced = basePrompt
        if input.styleImageCount > 0 {
            let sc = input.sourceImageCount
            let plural = sc > 1
            enhanced = "\(basePrompt)\n\n[Technická instrukce: První \(sc) obrázek\(plural ? "y" : "") \(plural ? "jsou" : "je") vstupní obsah k úpravě. Následující \(input.styleImageCount) obrázek\(input.styleImageCount > 1 ? "y" : "") \(input.styleImageCount > 1 ? "jsou" : "je") stylová reference - použij jejich vizuální styl, estetiku a umělecký přístup pro úpravu vstupního obsahu.]"

            if input.sourceImageCount > 1 && !input.multiRefBatch {
                enhanced += "\n\n[KOMPOZICE & OBSAH: Vytvoř jednu výslednou scénu, která kombinuje obsah ze všech vstupních obrázků. Použij stylové obrázky také jako kompoziční šablonu (rozvržení, póza, framing) pro výslednou scénu. Zachovej maximálně obličejovou podobnost osob ze vstupů a zachovej jejich klíčové objekty/rekvizity.]"
            }
            enhanced += "\n\n\(buildStyleStrengthInstruction(input.styleStrength))"
        }

        if input.assetImageCount > 0 {
            enhanced += "\n\n[PROPRIETÁRNÍ ASSET REFERENCE: Po stylových referencích následuje \(input.assetImageCount) obrázek\(input.assetImageCount > 1 ? "y" : "") proprietárních prvků (např. logo, klobouk, boty, produkt). Tyto assety NEBER jako styl. Použij je pouze jako obsahové/reference prvky pro přesný vzhled, tvar a umístění ve scéně.]"
        }

        return (basePrompt, enhanced)
    }
}
