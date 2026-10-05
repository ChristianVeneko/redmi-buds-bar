import SwiftUI

enum Theme {
    /// Xiaomi-style orange, slightly desaturated. Used only for selected state.
    static let accent = Color(red: 0.93, green: 0.48, blue: 0.20)
    static let cornerRadius: CGFloat = 12
    static let panelCornerRadius: CGFloat = 14
    static let panelWidth: CGFloat = 320
    static let maxPanelHeight: CGFloat = 640

    /// Flat, low-contrast fill shared by cards and unselected controls.
    static let cardFill = Color.primary.opacity(0.05)
    static let controlFill = Color.primary.opacity(0.06)
    /// Subtle tint of the selected control (paired with an accent foreground).
    static let selectedFill = accent.opacity(0.2)
    static let hairline = Color.primary.opacity(0.12)

    /// Quick spring used for selection changes; no animation when Reduce Motion is on.
    static func select(_ reduceMotion: Bool) -> Animation? { reduceMotion ? nil : .snappy(duration: 0.25) }
}

/// Flat card with an optional small uppercase title placed above it.
struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }
}

/// Subtle press feedback for custom buttons.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
