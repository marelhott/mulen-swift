//
//  WindowGlass.swift
//  MulenNano
//
//  Správná implementace průhledného okna s vibrancy:
//  NSVisualEffectView.blendingMode = .behindWindow sampuluje pixely za oknem (desktop/wallpaper).
//  NSWindow.isOpaque = false + backgroundColor = .clear dovolí SwiftUI vrstvám být průhledné.
//

import SwiftUI
import AppKit

// MARK: - Desktop vibrancy background

/// NSVisualEffectView s blendingMode .behindWindow — sampluje wallpaper za oknem.
/// Použij jako .background{} na root view.
struct DesktopVibrancyBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

// MARK: - Window transparency configurator

/// Nastaví NSWindow průhledným — nutné pro .behindWindow vibrancy.
/// Vloží se jako .background(WindowTransparency()) na root view.
struct WindowTransparency: NSViewRepresentable {
    func makeNSView(context: Context) -> _WTHelper { _WTHelper() }
    func updateNSView(_ nsView: _WTHelper, context: Context) {}
}

final class _WTHelper: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let w = window else { return }
        w.isOpaque = false
        w.backgroundColor = .clear
        w.titlebarAppearsTransparent = true
        w.hasShadow = true
    }
}
