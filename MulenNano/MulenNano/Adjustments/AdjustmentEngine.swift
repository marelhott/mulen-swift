//
//  AdjustmentEngine.swift
//  MulenNano
//
//  Reprodukovatelné editační schopnosti Apple Photos (PhotoImaging.framework),
//  přepsané na veřejné CoreImage filtry.
//
//  Photos používá (z dyld_info exportů) tyto PI*AdjustmentKey:
//  SmartColor / SmartBW / SmartTone, Curves, Levels, Definition, SelectiveColor,
//  WhiteBalance, Sharpen, NoiseReduction, Vignette, Grain, Retouch, RedEye,
//  Inpaint, Depth, Portrait, SemanticStyle …
//  Zdejší pipeline pokrývá veškeré zkopírovatelné (nedestruktivní) úpravy,
//  které nevyžadují Apple modely (Retouch/Clean-Up = vlastní CoreML).
//

import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import ImageIO

// MARK: - Stav úprav

/// Všechny hodnoty normalizované na ±1 (nebo 0…1), přesně jako posuvníky Photos.
/// `0` = výchozí/nulový zásah. Centrované posuvníky (Warmth/Tint/Vignette/Neutrals/Tone)
/// mají střed v 0 a jdou oběma směry.
struct AdjustmentState: Codable, Hashable, Sendable {
    // Světlo
    var exposure: Double = 0       // ±1 → EV ∓2.0
    var brilliance: Double = 0     // ±1 (clarity středotónů)
    var highlights: Double = 0     // ±1
    var shadows: Double = 0        // ±1
    var brightness: Double = 0     // ±1
    var contrast: Double = 0       // ±1
    var blackPoint: Double = 0     // ±1

    // Barva
    var saturation: Double = 0     // ±1
    var vibrance: Double = 0       // ±1
    var warmth: Double = 0         // ±1 (centrovaný)
    var tint: Double = 0           // ±1 (centrovaný)

    // Černobílá
    var blackAndWhite: Bool = false
    var bwIntensity: Double = 0    // 0…1 (síla desaturace)
    var bwNeutrals: Double = 0     // ±1 (centrovaný)
    var bwTone: Double = 0         // ±1 (centrovaný)

    // Detail
    var definition: Double = 0     // ±1 (místní kontrast / clarity)
    var sharpness: Double = 0      // 0…1
    var noiseReduction: Double = 0 // 0…1

    // Efekty
    var vignette: Double = 0       // ±1 (centrovaný; zápor = tmavý, + = světlý)
    var sepia: Double = 0          // 0…1
    var grain: Double = 0          // 0…1

    nonisolated var isDefault: Bool {
        exposure == 0 && brilliance == 0 && highlights == 0 && shadows == 0
        && brightness == 0 && contrast == 0 && blackPoint == 0
        && saturation == 0 && vibrance == 0 && warmth == 0 && tint == 0
        && blackAndWhite == false && bwIntensity == 0 && bwNeutrals == 0 && bwTone == 0
        && definition == 0 && sharpness == 0 && noiseReduction == 0
        && vignette == 0 && sepia == 0 && grain == 0
    }

    /// Souhrnný posuvník „Světlo" jako ve Photos (průměr Light hodnot).
    var lightSummary: Double {
        let v = [exposure, brilliance, highlights, shadows, brightness, contrast, blackPoint]
        return v.reduce(0, +) / Double(v.count)
    }

    /// Souhrn „Barva".
    var colorSummary: Double {
        let v = [saturation, vibrance, warmth, tint]
        return v.reduce(0, +) / Double(v.count)
    }

    /// Souhrn „Černobílá".
    var bwSummary: Double {
        blackAndWhite ? bwIntensity : 0
    }
}

// MARK: - Filtry (záložka Filtr) — CIPhotoEffect*

enum FilterPreset: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case original   = "Originál"
    case mono       = "Mono"
    case tonal      = "Tón"
    case noir       = "Noir"
    case fade       = "Blednutí"
    case chrome     = "Chrome"
    case process    = "Proces"
    case transfer   = "Přenos"
    case instant    = "Instant"
    case dramatic   = "Drama"
    case dramaticWarm = "Teplé drama"
    case dramaticCool = "Studené drama"
    case silverPlate  = "Stříbrný pleas"
    case idulette  = "IDU"

    var id: String { rawValue }

    /// SF Symbol / vizuální nápověda pro případ, kdy thumbnail není ready.
    var symbol: String {
        switch self {
        case .original: return "circle"
        case .mono, .tonal, .noir, .silverPlate: return "circle.lefthalf.filled"
        default: return "circle.righthalf.filled"
        }
    }

    nonisolated var ciFilterName: String? {
        switch self {
        case .original: return nil
        case .mono: return "CIPhotoEffectMono"
        case .tonal: return "CIPhotoEffectTonal"
        case .noir: return "CIPhotoEffectNoir"
        case .fade: return "CIPhotoEffectFade"
        case .chrome: return "CIPhotoEffectChrome"
        case .process: return "CIPhotoEffectProcess"
        case .transfer: return "CIPhotoEffectTransfer"
        case .instant: return "CIPhotoEffectInstant"
        case .dramatic: return "CIPhotoEffectNoir"
        case .dramaticWarm: return "CIPhotoEffectTransfer"
        case .dramaticCool: return "CIPhotoEffectProcess"
        case .silverPlate: return "CIPhotoEffectMono"
        case .idulette: return "CIPhotoEffectTonal"
        }
    }
}

// MARK: - Oříznutí / transformace

struct CropState: Codable, Hashable, Sendable {
    enum Aspect: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
        case freeform = "Volný"
        case original = "Původní"
        case square   = "Čtverec"
        case ratio_3_4  = "3:4"
        case ratio_4_3  = "4:3"
        case ratio_2_3  = "2:3"
        case ratio_3_2  = "3:2"
        case ratio_9_16 = "9:16"
        case ratio_16_9 = "16:9"
        case ratio_5_7  = "5:7"
        case ratio_7_5  = "7:5"
        case ratio_8_10 = "8:10"
        case ratio_10_8 = "10:8"

        var id: String { rawValue }
        var ratio: Double? {
            switch self {
            case .freeform, .original: return nil
            case .square: return 1
            case .ratio_3_4: return 3.0/4
            case .ratio_4_3: return 4.0/3
            case .ratio_2_3: return 2.0/3
            case .ratio_3_2: return 3.0/2
            case .ratio_9_16: return 9.0/16
            case .ratio_16_9: return 16.0/9
            case .ratio_5_7: return 5.0/7
            case .ratio_7_5: return 7.0/5
            case .ratio_8_10: return 8.0/10
            case .ratio_10_8: return 10.0/8
            }
        }
    }

    var aspect: Aspect = .original
    /// Normalizovaný ořezový rect v obraze (0…1).
    var rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    var straighten: Double = 0     // -45…45 (stupně)
    var flipHorizontal: Bool = false
    var flipVertical: Bool = false

    nonisolated var isDefault: Bool {
        aspect == .original && rect == CGRect(x: 0, y: 0, width: 1, height: 1)
        && straighten == 0 && !flipHorizontal && !flipVertical
    }
}

// MARK: - Renderovací pipeline

enum AdjustmentEngine {
    nonisolated static let context: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device)
        }
        return CIContext(options: [.useSoftwareRenderer: false])
    }()

    /// Aplikuje všechny úpravy (světlo → barva → detail → efekty → ČB → filtr → ořez).
    /// Pořadí odpovídá Photos (PAAdjustmentSerialization pipeline).
    nonisolated static func apply(to input: CIImage,
                      state: AdjustmentState,
                      filter: FilterPreset,
                      crop: CropState) -> CIImage {
        guard !state.isDefault || filter != .original || !crop.isDefault else { return input }

        var img = input
        img = applyWhiteBalance(img, state)
        img = applyLight(img, state)
        img = applyColor(img, state)
        img = applyDefinition(img, state)
        img = applySharpen(img, state)
        img = applyNoiseReduction(img, state)
        img = applyEffects(img, state)
        if state.blackAndWhite { img = applyBlackAndWhite(img, state) }
        if filter != .original, let name = filter.ciFilterName {
            img = applyFilter(name, to: img, filter: filter)
        }
        img = applyCrop(img, crop)
        return img
    }

    // MARK: Bílá rovnováha (warmth/tint) — CITemperatureAndTint
    nonisolated private static func applyWhiteBalance(_ image: CIImage, _ s: AdjustmentState) -> CIImage {
        guard s.warmth != 0 || s.tint != 0 else { return image }
        let f = CIFilter.temperatureAndTint()
        f.inputImage = image
        f.neutral = CIVector(x: CGFloat(6500 + s.warmth * 2500), y: CGFloat(0 + s.tint * 80))
        return f.outputImage ?? image
    }

    // MARK: Světlo
    nonisolated private static func applyLight(_ image: CIImage, _ s: AdjustmentState) -> CIImage {
        var out = image

        if s.exposure != 0 {
            let f = CIFilter.exposureAdjust()
            f.inputImage = out
            f.ev = Float(s.exposure * 2.0)
            out = f.outputImage ?? out
        }
        if s.highlights != 0 || s.shadows != 0 {
            let f = CIFilter.highlightShadowAdjust()
            f.inputImage = out
            f.highlightAmount = Float(1 + s.highlights * 0.5)
            f.shadowAmount   = Float(1 + s.shadows  * 0.5)
            out = f.outputImage ?? out
        }
        if s.brightness != 0 || s.contrast != 0 || s.blackPoint != 0 {
            let f = CIFilter.colorControls()
            f.inputImage = out
            f.brightness = Float(s.brightness * 0.12 - s.blackPoint * 0.08)
            f.contrast   = Float(1 + s.contrast * 0.35)
            f.saturation = 1.0
            out = f.outputImage ?? out
        }
        // Brilliance ≈ mírný místní kontrast + prosvětlení středotónů (Photos PAImaging ekvivalent).
        if s.brilliance != 0 {
            let f = CIFilter.highlightShadowAdjust()
            f.inputImage = out
            f.highlightAmount = Float(max(0, 1 - s.brilliance * 0.18))
            f.shadowAmount   = Float(max(0, 1 + s.brilliance * 0.25))
            out = f.outputImage ?? out
        }
        return out
    }

    // MARK: Barva
    nonisolated private static func applyColor(_ image: CIImage, _ s: AdjustmentState) -> CIImage {
        var out = image
        if s.saturation != 0 {
            let f = CIFilter.colorControls()
            f.inputImage = out
            f.saturation = Float(1 + s.saturation * 1.2)
            out = f.outputImage ?? out
        }
        if s.vibrance != 0 {
            let f = CIFilter.vibrance()
            f.inputImage = out
            f.amount = Float(s.vibrance * 1.0)
            out = f.outputImage ?? out
        }
        return out
    }

    // MARK: Detail
    nonisolated private static func applyDefinition(_ image: CIImage, _ s: AdjustmentState) -> CIImage {
        guard s.definition != 0 else { return image }
        // Definition = clarity / lokální kontrast → UnsharpMask s malým poloměrem.
        let f = CIFilter.unsharpMask()
        f.inputImage = image
        f.radius = 8
        f.intensity = Float(abs(s.definition) * 0.6) * (s.definition < 0 ? -1 : 1)
        return f.outputImage ?? image
    }

    nonisolated private static func applySharpen(_ image: CIImage, _ s: AdjustmentState) -> CIImage {
        guard s.sharpness != 0 else { return image }
        let f = CIFilter.sharpenLuminance()
        f.inputImage = image
        f.sharpness = Float(s.sharpness * 0.9)
        return f.outputImage ?? image
    }

    nonisolated private static func applyNoiseReduction(_ image: CIImage, _ s: AdjustmentState) -> CIImage {
        guard s.noiseReduction != 0 else { return image }
        guard let f = CIFilter(name: "CINoiseReduction") else { return image }
        f.setValue(image, forKey: kCIInputImageKey)
        f.setValue(s.noiseReduction * 0.16, forKey: "inputNoiseLevel")
        f.setValue(s.noiseReduction * 0.6,  forKey: "inputSharpness")
        return f.outputImage ?? image
    }

    // MARK: Efekty
    nonisolated private static func applyEffects(_ image: CIImage, _ s: AdjustmentState) -> CIImage {
        var out = image
        if s.vignette != 0 {
            if let f = CIFilter(name: "CIVignette") {
                f.setValue(out, forKey: kCIInputImageKey)
                f.setValue(abs(s.vignette) * 1.4, forKey: "inputIntensity")
                f.setValue(1.6, forKey: "inputRadius")
                f.setValue(s.vignette > 0 ? 1 : 0, forKey: "inputFalloff")
                out = f.outputImage ?? out
            }
        }
        if s.sepia != 0 {
            let f = CIFilter.sepiaTone()
            f.inputImage = out
            f.intensity = Float(s.sepia)
            out = f.outputImage ?? out
        }
        if s.grain != 0 {
            out = applyGrain(out, amount: s.grain)
        }
        return out
    }

    /// Filmové zrno — syntetický šum (Photos PIGrainAdjustment ekvivalent přes veřejné CI).
    nonisolated private static func applyGrain(_ image: CIImage, amount: Double) -> CIImage {
        let noise = CIFilter.randomGenerator().outputImage!
            .cropped(to: image.extent)
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.2])
        guard let composited = CIFilter(name: "CIHardLightBlendMode",
                                        parameters: [
                                            kCIInputImageKey: noise,
                                            kCIInputBackgroundImageKey: image
                                        ])?.outputImage else { return image }
        return composited.applyingFilter("CIColorControls",
                                         parameters: [
                                            inputBrightness: 0.0,
                                            inputContrast: amount * 0.25,
                                            inputSaturation: 0.0
                                         ])
    }

    // MARK: Černobílá
    nonisolated private static func applyBlackAndWhite(_ image: CIImage, _ s: AdjustmentState) -> CIImage {
        let mono = image.applyingFilter("CIPhotoEffectMono")
        let mix = CIFilter.colorControls()
        mix.inputImage = mono
        mix.contrast = Float(1 + s.bwTone * 0.3)
        mix.brightness = Float(s.bwNeutrals * 0.08)
        return mix.outputImage ?? mono
    }

    // MARK: Filtr (záložka Filtr)
    nonisolated private static func applyFilter(_ name: String, to image: CIImage, filter: FilterPreset) -> CIImage {
        var out = image
        if let f = CIFilter(name: name) {
            f.setValue(out, forKey: kCIInputImageKey)
            out = f.outputImage ?? out
        }
        // Odstiny drama — jemné teplé/studené posunutí
        switch filter {
        case .dramaticWarm:
            out = warmTint(out, strength: 0.18)
        case .dramaticCool:
            out = coolTint(out, strength: 0.18)
        default: break
        }
        return out
    }

    nonisolated private static func warmTint(_ image: CIImage, strength: CGFloat) -> CIImage {
        image.applyingFilter("CITemperatureAndTint",
                             parameters: ["inputNeutral": CIVector(x: 6500 - 1200 * strength, y: 0)])
    }
    nonisolated private static func coolTint(_ image: CIImage, strength: CGFloat) -> CIImage {
        image.applyingFilter("CITemperatureAndTint",
                             parameters: ["inputNeutral": CIVector(x: 6500 + 1200 * strength, y: 0)])
    }

    // MARK: Oříznutí / transformace
    nonisolated private static func applyCrop(_ image: CIImage, _ c: CropState) -> CIImage {
        var out = image
        if c.flipHorizontal || c.flipVertical {
            let scaleX: CGFloat = c.flipHorizontal ? -1 : 1
            let scaleY: CGFloat = c.flipVertical ? -1 : 1
            // Posun zpět do extentu
            out = out.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            out = out.transformed(by: CGAffineTransform(translationX: scaleX < 0 ? out.extent.width : 0,
                                                         y: scaleY < 0 ? out.extent.height : 0))
        }
        if c.straighten != 0 {
            let angle = CGFloat(c.straighten * .pi / 180)
            out = out.transformed(by: CGAffineTransform(rotationAngle: angle))
        }
        if c.rect != CGRect(x: 0, y: 0, width: 1, height: 1) {
            let e = out.extent
            let cropRect = CGRect(x: e.minX + c.rect.minX * e.width,
                                  y: e.minY + c.rect.minY * e.height,
                                  width: c.rect.width * e.width,
                                  height: c.rect.height * e.height)
            out = out.cropped(to: cropRect)
        }
        return out
    }

    // MARK: Render do NSImage / Data

    /// Render v plném rozlišení (pro finální uložení).
    nonisolated static func renderFullRes(_ image: CIImage) -> NSImage? {
        guard let cg = context.createCGImage(image, from: image.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: image.extent.width, height: image.extent.height))
    }

    /// Render omezený na `maxDimension` pixelů (pro rychlý náhled).
    nonisolated static func renderPreview(_ image: CIImage, maxDimension: CGFloat = 1400) -> NSImage? {
        let extent = image.extent
        let longest = Swift.max(extent.width, extent.height)
        let scale = min(1, maxDimension / longest)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }

    /// PNG data pro uložení (přes ImageIO, stejná cesta jako Photos export).
    nonisolated static func pngData(_ image: CIImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData,
                                                          "public.png" as CFString, 1, nil) else { return nil }
        guard let cg = context.createCGImage(image, from: image.extent) else { return nil }
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}

// MARK: - Konstanty pro CIColorControls (chybějící v CIFilterBuiltins extentions občas)
nonisolated private let inputBrightness = "inputBrightness"
nonisolated private let inputContrast = "inputContrast"
nonisolated private let inputSaturation = "inputSaturation"
