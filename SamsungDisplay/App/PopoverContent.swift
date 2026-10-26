import AppKit
import SwiftUI

struct PopoverContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Bindable var controller: ConnectionController
    @State private var draftLevel: Double?
    @State private var isDragging = false
    @State private var throttle = SliderThrottle()

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
        .task {
            while !Task.isCancelled {
                await controller.refreshPowerState()
                try? await Task.sleep(for: .seconds(3))
            }
        }
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
            volumeCard
            HStack(spacing: 12) {
                powerCard
                inputCard
            }
            RemotePad(controller: controller)
        }
    }

    private var volumeCard: some View {
        VStack(spacing: 10) {
            if controller.volume != nil {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: sliderBinding, in: 0...100, onEditingChanged: sliderEditingChanged)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 10) {
                    Button { controller.send(.volDown) } label: {
                        Label("Vol-", systemImage: "speaker.wave.1.fill").frame(maxWidth: .infinity)
                    }
                    Button { controller.send(.volUp) } label: {
                        Label("Vol+", systemImage: "speaker.wave.3.fill").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glass)
                .disabled(!isConnected)
            }
            Button { controller.send(.mute) } label: {
                Label(controller.isMuted == true ? "Unmute" : "Mute",
                      systemImage: controller.isMuted == true ? "speaker.slash.fill" : "speaker.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .disabled(!isConnected)
        }
        .glassCard()
    }

    private var powerCard: some View {
        VStack(spacing: 8) {
            Text(controller.powerState.map { "Power: \($0.label)" } ?? "Power")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button { controller.togglePower() } label: {
                Label(controller.powerState == .on ? "Power off" : "Power on", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .glassCard()
    }

    private var inputCard: some View {
        Menu {
            Button("Source") { controller.openInputSourceMenu() }
            Button("Next HDMI input") { controller.nextHDMIInput() }
        } label: {
            Label("Input", systemImage: "cable.connector.horizontal").frame(maxWidth: .infinity)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .disabled(!isConnected)
        .glassCard()
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

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { draftLevel ?? Double(controller.volume ?? 0) },
            set: { value in
                draftLevel = value
                if let level = throttle.submit(Int(value.rounded()), at: .now) { controller.setVolume(level) }
            }
        )
    }

    private func sliderEditingChanged(_ editing: Bool) {
        isDragging = editing
        guard !editing else { return }
        if let level = throttle.flush(at: .now) { controller.setVolume(level) }
        Task {
            try? await Task.sleep(for: .seconds(1))
            if !isDragging { draftLevel = nil }
        }
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
