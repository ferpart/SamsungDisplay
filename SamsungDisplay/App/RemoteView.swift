import SwiftUI

struct RemoteView: View {
    @Bindable var controller: ConnectionController

    private var isConnected: Bool { controller.state == .connected }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                powerCard
                inputCard
                RemotePad(controller: controller)
            }
        }
        .padding(14)
        .frame(width: 280)
        .containerBackground(.thinMaterial, for: .window)
        .onAppear { NSApp.activate() }
        .task {
            while !Task.isCancelled {
                await controller.refreshPowerState()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private var powerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Power").font(.headline)
                Text(controller.powerState?.label ?? "Unknown").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { controller.togglePower() } label: {
                Label(controller.powerState == .on ? "Power off" : "Power on", systemImage: "power")
            }
            .buttonStyle(.glass)
        }
        .glassCard()
    }

    private var inputCard: some View {
        VStack(spacing: 10) {
            Button { controller.openInputSourceMenu() } label: {
                Label("Source", systemImage: "rectangle.on.rectangle").frame(maxWidth: .infinity)
            }
            Button { controller.nextHDMIInput() } label: {
                Label("Next HDMI input", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.glass)
        .disabled(!isConnected)
        .glassCard()
    }
}
