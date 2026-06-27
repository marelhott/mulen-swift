//
//  SidebarItem.swift
//  MulenNano
//
//  Informační architektura sidebaru — dvě sekce: Knihovna a Nástroje.
//  (Sekce style / model / lora z webové verze jsou záměrně vynechané.)
//

import SwiftUI

enum SidebarItem: String, Identifiable, CaseIterable {
    // MARK: Knihovna
    case all
    case collections
    case recentlyDeleted

    // MARK: Nástroje
    case generate
    case upscaler
    case faceSwap
    case reframe
    case batch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:             return "Vše"
        case .collections:     return "Kolekce"
        case .recentlyDeleted: return "Naposledy smazané"
        case .generate:        return "Generovat"
        case .upscaler:        return "AI Upscaler"
        case .faceSwap:        return "Face Swap"
        case .reframe:         return "Reframe"
        case .batch:           return "Batch"
        }
    }

    var systemImage: String {
        switch self {
        case .all:             return "photo.on.rectangle.angled"
        case .collections:     return "rectangle.stack"
        case .recentlyDeleted: return "trash"
        case .generate:        return "sparkles"
        case .upscaler:        return "arrow.up.left.and.arrow.down.right"
        case .faceSwap:        return "person.crop.rectangle"
        case .reframe:         return "crop"
        case .batch:           return "square.grid.2x2"
        }
    }

    /// Položky sekce „Knihovna".
    static let library: [SidebarItem] = [.all, .collections, .recentlyDeleted]

    /// Položky sekce „Nástroje".
    static let tools: [SidebarItem] = [.generate, .upscaler, .faceSwap, .reframe, .batch]
}
