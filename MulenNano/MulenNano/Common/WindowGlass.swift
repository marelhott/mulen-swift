//
//  WindowGlass.swift
//  MulenNano
//
//  Zpřístupní NSWindow a nastaví průhledné pozadí — desktop probíjí skrz glass materiály.
//

import SwiftUI
import AppKit

/// Vloží se do view hierarchy; jakmile se view připojí k oknu, nastaví ho průhledným.
struct WindowGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> _WindowGlassHelper { _WindowGlassHelper() }
    func updateNSView(_ nsView: _WindowGlassHelper, context: Context) {}
}

final class _WindowGlassHelper: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let w = window else { return }
        w.isOpaque = false
        w.backgroundColor = .clear
        w.titlebarAppearsTransparent = true
        w.hasShadow = true
    }
}
