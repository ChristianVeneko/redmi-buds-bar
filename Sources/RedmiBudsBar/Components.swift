import BudsProtocol
import SwiftUI

/// Circular battery gauge with a charging bolt.
struct BatteryRing: View {
    let title: String
    let level: BatteryLevel?

    private var color: Color {
        guard let level else { return .secondary }
        if level.isCharging { return .green }
        if level.percent <= 15 { return .red }
        if level.percent <= 30 { return .orange }
        return Theme.accent
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.1), lineWidth: 6)
                if let level {
                    Circle()
                        .trim(from: 0, to: CGFloat(level.percent) / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text(verbatim: level.map { "\($0.percent)" } ?? "\u{2014}")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    if level?.isCharging == true {
                        Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(.green)
                    }
                }
            }
            .frame(width: 62, height: 62)
            .animation(.smooth, value: level)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(level.map { "\($0.percent)%" + ($0.isCharging ? ", " + tr("charging") : "") } ?? tr("Not reported"))
    }
}

/// Selectable tile with an animated highlight shared between tiles.
struct ModeTile: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 20, weight: .medium))
                Text(title).font(.caption.weight(.medium)).multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06))
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.accent)
                            .matchedGeometryEffect(id: "modeSelection", in: namespace)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? Theme.accent : Color.primary.opacity(0.08), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SettingToggle: View {
    let title: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(title, isOn: Binding(get: { isOn }, set: onChange))
            .toggleStyle(.switch)
            .tint(Theme.accent)
            .controlSize(.small)
            .font(.callout)
    }
}
