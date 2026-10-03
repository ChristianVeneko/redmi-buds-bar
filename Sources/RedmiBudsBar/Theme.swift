import SwiftUI

enum Theme {
    /// Accent shared by all selectable controls (Xiaomi-style orange; readable in light and dark mode).
    static let accent = Color(red: 1.0, green: 0.41, blue: 0.0)
    static let cornerRadius: CGFloat = 14
    static let panelWidth: CGFloat = 320
}

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }
}
