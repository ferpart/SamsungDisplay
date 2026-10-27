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
    let isResizable: Bool

    func makeNSView(context: Context) -> WindowGlass { WindowGlass(isResizable: isResizable) }
    func updateNSView(_ nsView: WindowGlass, context: Context) {}

    final class WindowGlass: NSGlassEffectView {
        let isResizable: Bool

        init(isResizable: Bool) {
            self.isResizable = isResizable
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            if !isResizable { window.styleMask.remove(.resizable) }
        }
    }
}

extension View {
    func glassWindowBackground(isResizable: Bool = false) -> some View {
        containerBackground(.clear, for: .window)
            .background(GlassWindowBody(isResizable: isResizable).ignoresSafeArea())
    }
}
