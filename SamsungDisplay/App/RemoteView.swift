import SwiftUI

struct RemoteView: View {
    @Bindable var controller: ConnectionController

    private var isConnected: Bool { controller.state == .connected }
    private var isOn: Bool { controller.powerState == .on }

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            VStack(spacing: 14) {
                header
                SoundButtonRow(controller: controller, diameter: 34)
                RemotePad(controller: controller).padding(.top, 4)
                Divider()
                VStack(spacing: 2) {
                    MenuRow(title: "Source", systemImage: "rectangle.on.rectangle") { controller.openInputSourceMenu() }
                    MenuRow(title: "Next input", systemImage: "rectangle.2.swap") { controller.nextHDMIInput() }
                }
                .padding(.horizontal, -8)
                .disabled(!isConnected)
            }
        }
        .padding(16)
        .frame(width: 280)
        .glassWindowBackground()
        .onAppear { NSApp.activate() }
        .task {
            while !Task.isCancelled {
                await controller.refreshPowerState()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(controller.monitorName ?? "Samsung monitor").font(.headline).lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(isOn ? Color.green : .secondary).frame(width: 7, height: 7)
                    Text(controller.powerState?.label ?? "Unknown").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            RoundIconButton(systemImage: "power", label: isOn ? "Power off" : "Power on", diameter: 34) { controller.togglePower() }
        }
    }
}
