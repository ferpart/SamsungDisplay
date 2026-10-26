import AppKit
import SwiftUI

struct PopoverContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Bindable var controller: ConnectionController

    private var isConnected: Bool { controller.state == .connected }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                header
                switch controller.state {
                case .noIP: setUpCard
                case .unauthorized: recoveryCard
                default: controls
                }
                footer
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "display").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.monitorName ?? "Samsung monitor").font(.headline)
                HStack(spacing: 6) {
                    if controller.state == .connecting {
                        ProgressView().controlSize(.mini)
                    } else {
                        Circle().fill(statusColor).frame(width: 8, height: 8)
                    }
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .glassCard()
    }

    private var controls: some View {
        VStack(spacing: 12) {
            SoundButtonRow(controller: controller).glassCard()
            Button { open("remote") } label: {
                Label("Remote", systemImage: "av.remote").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .glassCard()
        }
    }

    private var setUpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No monitor is set up yet.").font(.callout)
            Button("Set up your monitor…") { open("onboarding") }
                .buttonStyle(.glassProminent)
        }
        .glassCard()
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your monitor rejected the app. On the monitor, open Settings → All Settings → Connections → Device Connect Manager → Device List → SamsungDisplay → Allow.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Wipe token and reconnect") { controller.wipeTokenAndReconnect() }
                .buttonStyle(.glassProminent)
        }
        .glassCard()
    }

    private var footer: some View {
        HStack {
            Button("Settings…") { open("settings") }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: [.command])
        }
        .buttonStyle(.glass)
    }

    private var statusText: String {
        controller.state == .noIP ? "Not set up" : controller.statusMessage
    }

    private var statusColor: Color {
        switch controller.state {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected, .noIP, .unauthorized: .red
        }
    }

    private func open(_ windowID: String) {
        openWindow(id: windowID)
        NSApp.activate()
        dismiss()
    }
}
