import SwiftUI
import AppKit   // NSApp.activate

/// MenuBarExtra popover body. Bound to the shared ConnectionController.
///
/// Layout (top-to-bottom):
///   * Icon-only button row: Mute, Vol-, Vol+
///   * Status line (state-driven; sticky-deny recovery block when .unauthorized)
///   * Divider
///   * "Settings..."  (opens Window("Settings"); brings app to front; dismisses popover)
///   * "Quit"         (NSApp.terminate)
///
/// Per CONTEXT decisions:
///   * Click-only interaction. No Tab focus or keyboard shortcuts.
///   * Buttons disabled when state != .connected.
///   * No Material / custom chrome — Phase 5 owns polish.
struct PopoverContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Bindable var controller: ConnectionController

    private let popoverWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            buttonRow
            statusLine
            Divider()
            Button("Settings…") { openSettings() }
                .buttonStyle(.borderless)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(12)
        .frame(width: popoverWidth)
    }

    // MARK: - Pieces

    private var buttonRow: some View {
        HStack(spacing: 16) {
            Button { controller.send(.mute) } label: {
                Label("Mute", systemImage: "speaker.slash.fill")
            }
            Button { controller.send(.volDown) } label: {
                Label("Vol-", systemImage: "speaker.wave.1.fill")
            }
            Button { controller.send(.volUp) } label: {
                Label("Vol+", systemImage: "speaker.wave.3.fill")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .controlSize(.large)
        .disabled(controller.state != .connected)
        .help(buttonHelpText)
    }

    @ViewBuilder private var statusLine: some View {
        switch controller.state {
        case .connected:
            Text("Connected").foregroundStyle(.secondary)
        case .connecting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Reconnecting…").foregroundStyle(.secondary)
            }
        case .disconnected:
            Text("Disconnected").foregroundStyle(.secondary)
        case .noIP:
            Text("Not connected — set monitor IP in Settings").foregroundStyle(.secondary)
        case .unauthorized:
            recoveryHelpBlock
        }
    }

    private var recoveryHelpBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Samsung monitor rejected the app. On your TV, go to Settings → All Settings → Connections → Device Connect Manager → Device List → SamsungDisplay → Allow.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Wipe token and reconnect") {
                controller.wipeTokenAndReconnect()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var buttonHelpText: String {
        switch controller.state {
        case .connected: ""
        case .connecting: "Reconnecting — please wait"
        case .disconnected: "Disconnected"
        case .noIP: "Set the monitor IP in Settings first"
        case .unauthorized: "Pairing rejected — see recovery steps below"
        }
    }

    /// 02-RESEARCH.md Pattern 5 + Pitfall #1: open the Settings window,
    /// force the app to the front (LSUIElement=true apps don't auto-activate),
    /// and dismiss the popover via @Environment(\.dismiss).
    private func openSettings() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
        dismiss()
    }
}
