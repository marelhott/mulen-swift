//
//  ImageExport.swift
//  MulenNano
//
//  Uložení obrázku na disk přes nativní NSSavePanel.
//

import AppKit
import UniformTypeIdentifiers

enum ImageExport {
    static func save(_ data: Data, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedName
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}
