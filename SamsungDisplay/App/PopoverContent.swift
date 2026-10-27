import AppKit
import SwiftUI

struct PopoverContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Bindable var controller: ConnectionController

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                header
                switch controller.state {
                case .noIP: setUpSection
                case .unauthorized: recoverySection
                default: controls
                }
                Divider().padding(.horizontal, 8)
                VStack(spacing: 0) {
                    MenuRow(title: "Settings…") { open("settings") }
                    MenuRow(title: "Quit SamsungDisplay") { NSApp.terminate(nil) }
                        .keyboardShortcut("q", modifiers: [.command])
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(width: 290)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                monitorName
                Spacer()
                status
            }
            VStack(alignment: .leading, spacing: 2) {
                monitorName
                status
            }
        }
        .padding(.horizontal, 8)
    }

    private var monitorName: some View {
        Text(controller.monitorName ?? "Samsung monitor").font(.headline).lineLimit(1)
    }

    private var status: some View {
        HStack(spacing: 5) {
            if controller.state == .connecting {
                ProgressView().controlSize(.mini)
            } else {
                Circle().fill(statusColor).frame(width: 7, height: 7)
            }
            Text(statusText).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var controls: some View {
        SoundButtonRow(controller: controller)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        Divider().padding(.horizontal, 8)
        Text("Monitor").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 8)
        MenuRow(title: "Remote", systemImage: "av.remote", showsChevron: true) { open("remote") }
    }

    private var setUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No monitor is set up yet.").font(.callout)
            Button("Set up your monitor…") { open("onboarding") }
                .buttonStyle(.glassProminent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var recoverySection: some View {
        Text("The monitor rejected the app. Allow SamsungDisplay in the Device Connect Manager of the monitor. Then select Wipe token and re-pair in Settings.")
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
