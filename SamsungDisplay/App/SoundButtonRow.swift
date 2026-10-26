import SwiftUI

struct SoundButtonRow: View {
    @Bindable var controller: ConnectionController
    var diameter: CGFloat = 30

    var body: some View {
        HStack(spacing: 8) {
            RoundIconButton(systemImage: "speaker.slash.fill", label: "Mute", diameter: diameter) { controller.send(.mute) }
            Spacer()
            RoundIconButton(systemImage: "speaker.minus.fill", label: "Volume down", diameter: diameter) { controller.send(.volDown) }
            RoundIconButton(systemImage: "speaker.plus.fill", label: "Volume up", diameter: diameter) { controller.send(.volUp) }
        }
        .disabled(controller.state != .connected)
    }
}
