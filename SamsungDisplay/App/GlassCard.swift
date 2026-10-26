import SwiftUI

extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
