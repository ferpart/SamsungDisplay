import AppKit
import SwiftUI

struct RemotePad: View {
    @Bindable var controller: ConnectionController
    @State private var popoverWindow = WeakWindow()
    @State private var keyMonitor: Any?

    private var isConnected: Bool { controller.state == .connected }

    var body: some View {
        VStack(spacing: 14) {
            clickpad.opacity(isConnected ? 1 : 0.5)
            HStack(spacing: 36) {
                RoundIconButton(systemImage: "chevron.left", label: "Back", diameter: 46) { controller.send(.back) }
                RoundIconButton(systemImage: "house", label: "Home", diameter: 46) { controller.send(.home) }
            }
        }
        .disabled(!isConnected)
        .background(WindowReader(window: popoverWindow))
        .onAppear(perform: installKeyMonitor)
        .onDisappear(perform: removeKeyMonitor)
    }

    private var clickpad: some View {
        ZStack {
            Circle().fill(Color.primary.opacity(0.08))
            Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            arrow("chevron.up", key: .up).offset(y: -72)
            arrow("chevron.down", key: .down).offset(y: 72)
            arrow("chevron.left", key: .left).offset(x: -72)
            arrow("chevron.right", key: .right).offset(x: 72)
            Button { controller.send(.enter) } label: {
                Text("OK").font(.headline).frame(width: 74, height: 74).contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("OK")
        }
        .frame(width: 196, height: 196)
    }

    private func arrow(_ systemImage: String, key: SamsungCommand.Key) -> some View {
        HoldRepeatButton(systemImage: systemImage, label: key.rawValue) { controller.send(key) }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [controller, popoverWindow] event in
            let keyCode = event.keyCode
            let windowNumber = event.windowNumber
            let handled = MainActor.assumeIsolated {
                guard controller.state == .connected,
                      windowNumber == popoverWindow.window?.windowNumber,
                      let key = RemoteKeyMapping.key(forKeyCode: keyCode)
                else { return false }
                controller.send(key)
                return true
            }
            return handled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }
}

private struct HoldRepeatButton: View {
    let systemImage: String
    let label: String
    let send: () -> Void
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 40, height: 40)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in begin() }.onEnded { _ in end() })
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }

    private func begin() {
        guard repeatTask == nil else { return }
        send()
        repeatTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            while !Task.isCancelled {
                send()
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    private func end() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}

@MainActor
private final class WeakWindow {
    weak var window: NSWindow?
}

private struct WindowReader: NSViewRepresentable {
    let window: WeakWindow

    func makeNSView(context: Context) -> NSView { WindowTrackingView(window: window) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowTrackingView: NSView {
        let box: WeakWindow
        init(window: WeakWindow) {
            box = window
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            MainActor.assumeIsolated { box.window = window }
        }
    }
}
