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
        static let containerID = NSUserInterfaceItemIdentifier("GlassWindowContainer")

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window.contentView?.identifier != Self.containerID, let hosting = window.contentView else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            let bounds = NSRect(origin: .zero, size: window.contentRect(forFrameRect: window.frame).size)
            let container = NSView(frame: bounds)
            container.identifier = Self.containerID
            let glass = NSGlassEffectView(frame: bounds)
            glass.autoresizingMask = [.width, .height]
            hosting.frame = bounds
            hosting.autoresizingMask = [.width, .height]
            window.contentView = container
            container.addSubview(glass)
            container.addSubview(hosting)
        }
    }
}

extension View {
    func glassWindowBackground() -> some View {
        containerBackground(.clear, for: .window)
            .background(GlassWindowBody())
    }
}
