//
//  WindowGlass.swift
//  MulenNano
//
//  Configures the main window as an opaque Photos-style surface.
//

import SwiftUI
import AppKit

struct PhotosWindowConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> _WTHelper { _WTHelper() }
    func updateNSView(_ nsView: _WTHelper, context: Context) {}
}

final class _WTHelper: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let w = window else { return }
        w.isOpaque = true
        w.backgroundColor = .white
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.titlebarSeparatorStyle = .none
        w.styleMask.insert(.fullSizeContentView)
        w.isMovableByWindowBackground = false
        w.hasShadow = false
    }
}
