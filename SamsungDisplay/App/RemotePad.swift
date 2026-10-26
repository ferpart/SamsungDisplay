import AppKit
import SwiftUI

struct RemotePad: View {
    @Bindable var controller: ConnectionController
    @State private var popoverWindow = WeakWindow()
    @State private var keyMonitor: Any?

    private var isConnected: Bool { controller.state == .connected }

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                plain("Back", systemImage: "arrow.uturn.backward", key: .back)
                arrow("chevron.up", key: .up)
                plain("Home", systemImage: "house", key: .home)
            }
            GridRow {
                arrow("chevron.left", key: .left)
                plain("OK", systemImage: nil, key: .enter)
                arrow("chevron.right", key: .right)
            }
            GridRow {
                plain("Source", systemImage: "rectangle.on.rectangle", key: .source)
                arrow("chevron.down", key: .down)
                Color.clear.frame(height: 1)
            }
        }
        .disabled(!isConnected)
        .glassCard()
        .background(WindowReader(window: popoverWindow))
        .onAppear(perform: installKeyMonitor)
        .onDisappear(perform: removeKeyMonitor)
    }

    private func plain(_ title: String, systemImage: String?, key: SamsungCommand.Key) -> some View {
        Button { controller.send(key) } label: {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else {
                    Text(title).bold()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(title)
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
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)
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
