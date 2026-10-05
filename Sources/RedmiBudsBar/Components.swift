import BudsProtocol
import SwiftUI

/// Circular battery gauge with a charging bolt. The arc fills from 0 on appear and animates on change.
struct BatteryRing: View {
    let title: String
    let level: BatteryLevel?
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        guard let level else { return .secondary }
        if level.isCharging { return .green }
        if level.percent <= 15 { return .red }
        if level.percent <= 30 { return .orange }
        return Color.primary.opacity(0.8)
    }

    private var target: Double { Double(level?.percent ?? 0) / 100 }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 5)
                if level != nil {
                    Circle()
                        .trim(from: 0, to: shown)
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text(verbatim: level.map { "\($0.percent)" } ?? "\u{2014}")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if level?.isCharging == true {
                        Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(.green)
                    }
                }
            }
            .frame(width: 50, height: 50)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear { animate(to: target, duration: 0.7) }
        .onChange(of: level?.percent) { animate(to: target, duration: 0.45) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(level.map { "\($0.percent)%" + ($0.isCharging ? ", " + tr("charging") : "") } ?? tr("Not reported"))
    }

    private func animate(to value: Double, duration: Double) {
        if reduceMotion { shown = value } else { withAnimation(.smooth(duration: duration)) { shown = value } }
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
                Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                Text(title).font(.caption.weight(.medium)).multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(isSelected ? Theme.accent : Color.primary.opacity(0.85))
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.controlFill)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.selectedFill)
                            .matchedGeometryEffect(id: "modeSelection", in: namespace)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct Chip: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Theme.accent : Color.primary.opacity(0.85))
                .background {
                    ZStack {
                        Capsule().fill(Theme.controlFill)
                        if isSelected {
                            Capsule().fill(Theme.selectedFill).matchedGeometryEffect(id: "chipSelection", in: namespace)
                        }
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Flat segmented control with a sliding selection indicator.
struct SegmentedControl<T: Hashable>: View {
    let options: [T]
    let selection: T
    let title: (T) -> String
    let onSelect: (T) -> Void
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(Theme.select(reduceMotion)) { onSelect(option) }
                } label: {
                    Text(title(option))
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(isSelected ? Theme.accent : Color.primary.opacity(0.8))
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.selectedFill)
                                    .matchedGeometryEffect(id: "segmentSelection", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Theme.controlFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// Connection status dot; pulses while `pulsing` (connecting).
struct StatusDot: View {
    let color: Color
    let pulsing: Bool
    @State private var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .opacity(dimmed ? 0.3 : 1)
            .scaleEffect(dimmed ? 0.75 : 1)
            .onAppear(perform: update)
            .onChange(of: pulsing) { update() }
    }

    private func update() {
        if pulsing && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { dimmed = true }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { dimmed = false }
        }
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
