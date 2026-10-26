import AppKit
import SwiftUI

extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

private struct GlassWindowBody: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Tracker() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Tracker: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !(window.contentView is NSGlassEffectView), let hosting = window.contentView else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            let glass = NSGlassEffectView()
            glass.contentView = hosting
            window.contentView = glass
        }
    }
}

extension View {
    func glassWindowBackground() -> some View {
        containerBackground(.clear, for: .window)
            .background(GlassWindowBody())
    }
}
