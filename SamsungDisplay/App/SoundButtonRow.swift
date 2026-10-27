import SwiftUI

struct SoundButtonRow: View {
    @Bindable var controller: ConnectionController
    var height: CGFloat = 30

    var body: some View {
        HStack(spacing: 0) {
            segment("speaker.slash.fill", label: "Mute", key: .mute)
            divider
            segment("speaker.minus.fill", label: "Volume down", key: .volDown)
            divider
            segment("speaker.plus.fill", label: "Volume up", key: .volUp)
        }
        .glassEffect(.regular, in: .capsule)
        .disabled(controller.state != .connected)
    }

    private var divider: some View {
        Divider().frame(height: height * 0.5)
    }

    private func segment(_ systemImage: String, label: String, key: SamsungCommand.Key) -> some View {
        Button { controller.send(key) } label: {
            Image(systemName: systemImage)
                .font(.system(size: height * 0.4, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(.rect)
        }
        .buttonStyle(PillSegmentStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct PillSegmentStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.4)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.15 : 0)).padding(3))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
