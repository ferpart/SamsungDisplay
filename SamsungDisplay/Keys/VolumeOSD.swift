import AppKit
import SwiftUI

struct VolumeOSDView: View {
    let level: Int?
    let muted: Bool
    var pulse = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 26, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: pulse)
                .frame(width: 40)
            if let level {
                ProgressView(value: Double(muted ? 0 : level), total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 180)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .capsule)
        .padding(24)
    }

    private var symbolName: String {
        if muted { return "speaker.slash.fill" }
        switch level {
        case nil: return "speaker.wave.2.fill"
        case 0?: return "speaker.fill"
        case let level? where level < 34: return "speaker.wave.1.fill"
        case let level? where level < 67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

@MainActor
final class VolumeOSD {
    private let panel: NSPanel
    private let hostingView = NSHostingView(rootView: VolumeOSDView(level: nil, muted: false))
    private var pulse = 0
    private var hideTask: Task<Void, Never>?

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView = hostingView
    }

    func show(level: Int?, muted: Bool, on screen: NSScreen?) {
        pulse += 1
        hostingView.rootView = VolumeOSDView(level: level, muted: muted, pulse: pulse)
        let size = hostingView.fittingSize
        let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.setFrame(
            NSRect(x: visibleFrame.midX - size.width / 2, y: visibleFrame.minY + 40, width: size.width, height: size.height),
            display: true
        )
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let panel = self?.panel else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }
}

#Preview("No level") {
    VolumeOSDView(level: nil, muted: false)
}

#Preview("Muted with level") {
    VolumeOSDView(level: 40, muted: true)
}
