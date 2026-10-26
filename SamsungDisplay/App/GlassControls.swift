import SwiftUI

struct RoundIconButton: View {
    let systemImage: String
    let label: String
    var diameter: CGFloat = 30
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.38, weight: .medium))
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .opacity(isEnabled ? 1 : 0.4)
        .help(label)
        .accessibilityLabel(label)
    }
}

struct MenuRow: View {
    let title: String
    var systemImage: String?
    var showsChevron = false
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 26, height: 26)
                        .background(.quaternary, in: .circle)
                }
                Text(title)
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, systemImage == nil ? 3 : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .background(isHovering && isEnabled ? Color.primary.opacity(0.1) : .clear, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovering = $0 }
    }
}
