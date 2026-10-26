import SwiftUI

struct SoundButtonRow: View {
    @Bindable var controller: ConnectionController

    var body: some View {
        HStack(spacing: 10) {
            button("Mute", systemImage: "speaker.slash.fill", key: .mute)
            button("Vol-", systemImage: "speaker.minus.fill", key: .volDown)
            button("Vol+", systemImage: "speaker.plus.fill", key: .volUp)
        }
        .buttonStyle(.glass)
        .disabled(controller.state != .connected)
    }

    private func button(_ title: String, systemImage: String, key: SamsungCommand.Key) -> some View {
        Button { controller.send(key) } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity)
        }
        .help(title)
        .accessibilityLabel(title)
    }
}
