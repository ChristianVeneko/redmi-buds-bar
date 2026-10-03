import BudsProtocol
import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Root of the menu bar window.
struct PanelView: View {
    @Bindable var model: BudsViewModel
    @State private var contentHeight: CGFloat = 400
    @State private var showSettings = false
    private let localizer = Localizer.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HeaderView(model: model)
                if model.connection == .connected {
                    let caps = model.budsModel
                    BatteryCard(battery: model.state.battery, position: model.state.position)
                    if caps.hasNoiseControl { NoiseCard(model: model) }
                    if caps.hasEqualizer { EqualizerCard(model: model) }
                    if ExtrasCard.hasContent(model) { ExtrasCard(model: model) }
                    if caps.hasGestures, !model.state.gestures.isEmpty { GesturesCard(model: model) }
                    if !caps.isTestedOnHardware {
                        Text(tr("Support for this model has not been tested on hardware."))
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                } else {
                    OfflineCard(model: model)
                }
                if showSettings { SettingsCard(model: model) }
                FooterView(showSettings: $showSettings)
            }
            .padding(12)
            .background(GeometryReader { Color.clear.preference(key: ContentHeightKey.self, value: $0.size.height) })
        }
        .scrollIndicators(.hidden)
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        .frame(width: Theme.panelWidth, height: min(max(contentHeight, 120), 640))
        .animation(.smooth(duration: 0.25), value: model.connection)
        .environment(\.locale, localizer.locale)
        .tint(Theme.accent)
    }
}

struct HeaderView: View {
    let model: BudsViewModel

    private var dotColor: Color {
        switch model.connection {
        case .connected: .green
        case .connecting: .orange
        case .disconnected, .deviceNotFound: .secondary
        }
    }

    private var statusText: String {
        switch model.connection {
        case .connected: tr("Connected")
        case .connecting: tr("Connecting...")
        case .disconnected: tr("Disconnected")
        case .deviceNotFound: tr("No paired REDMI Buds found")
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "earbuds")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: model.state.name ?? model.deviceName).font(.headline)
                HStack(spacing: 5) {
                    Circle().fill(dotColor).frame(width: 7, height: 7)
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                model.refreshOrReconnect()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help(model.connection == .connected ? tr("Refresh") : tr("Reconnect"))
        }
        .padding(.horizontal, 4)
    }
}

struct OfflineCard: View {
    let model: BudsViewModel

    var body: some View {
        Card {
            VStack(spacing: 8) {
                Text(model.connection == .deviceNotFound
                     ? tr("Pair your REDMI Buds in System Settings, then reconnect.")
                     : tr("Open the case or connect the earbuds to this Mac."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let error = model.lastError {
                    Text(verbatim: error).font(.caption2).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Button(tr("Reconnect")) { model.reconnect() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.connection == .connecting)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct BatteryCard: View {
    let battery: BatteryStatus
    let position: EarbudsPositionFlags?

    private var hint: String? {
        if battery.case == nil { return tr("Case closed or not reported") }
        if let position, position.leftInCase, position.rightInCase { return tr("Earbuds are in the case") }
        return nil
    }

    var body: some View {
        Card(title: tr("Battery")) {
            HStack(alignment: .top, spacing: 8) {
                BatteryRing(title: tr("Left"), level: battery.left)
                BatteryRing(title: tr("Right"), level: battery.right)
                BatteryRing(title: tr("Case"), level: battery.case)
            }
            if let hint {
                Text(hint).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

struct NoiseCard: View {
    let model: BudsViewModel
    @Namespace private var namespace

    var body: some View {
        let state = model.state
        let caps = model.budsModel
        Card(title: tr("Noise control")) {
            HStack(spacing: 8) {
                ForEach(model.budsModel.ambientSoundModes, id: \.self) { mode in
                    ModeTile(title: mode.title, symbol: mode.symbol, isSelected: state.noiseMode == mode, namespace: namespace) {
                        withAnimation(.spring(duration: 0.3)) { model.setNoiseMode(mode) }
                    }
                }
            }
            if state.noiseMode != .transparency, let strength = state.noiseCancellingStrength {
                levelPicker(
                    title: tr("Noise cancelling level"),
                    options: options(caps.noiseCancellingStrengths, including: strength),
                    selection: strength, label: \.title, set: model.setNoiseCancellingStrength)
            }
            if state.noiseMode == .transparency, let strength = state.transparencyStrength {
                levelPicker(
                    title: tr("Transparency type"), options: options(caps.transparencyStrengths, including: strength),
                    selection: strength, label: \.title, set: model.setTransparencyStrength)
            }
        }
    }

    /// The model's options, plus the reported value if the model table does not list it.
    private func options<T: Hashable>(_ listed: [T], including current: T) -> [T] {
        listed.contains(current) ? listed : listed + [current]
    }

    private func levelPicker<T: Hashable>(
        title: String, options: [T], selection: T, label: KeyPath<T, String>, set: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Picker(title, selection: Binding(get: { selection }, set: set)) {
                ForEach(options, id: \.self) { Text($0[keyPath: label]).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

struct EqualizerCard: View {
    let model: BudsViewModel
    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 6)]

    var body: some View {
        let state = model.state
        let caps = model.budsModel
        Card(title: tr("Equalizer")) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(caps.equalizerPresets.filter { $0 != .custom }, id: \.self) { preset in
                    Chip(title: preset.title, isSelected: state.equalizerPreset == preset) { model.setEqualizerPreset(preset) }
                }
                if caps.supportsCustomEqualizer {
                    ForEach(CustomEqualizerPreset.allCases, id: \.self) { preset in
                        Chip(title: preset.title, isSelected: model.activeCustomPreset == preset) { model.applyCustomPreset(preset) }
                    }
                }
            }
            if let active = model.activeCustomPreset, active.suggestsNoiseCancelling, state.noiseMode != .noiseCancelling {
                Button {
                    withAnimation { model.setNoiseMode(.noiseCancelling) }
                } label: {
                    Label(tr("Switch to noise cancelling for immersion"), systemImage: "headphones")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct ExtrasCard: View {
    let model: BudsViewModel

    /// Whether the model offers anything in this card.
    static func hasContent(_ model: BudsViewModel) -> Bool {
        let caps = model.budsModel
        let state = model.state
        return caps.supportsFindDevice
            || (caps.supportsWearingDetection && state.wearingDetection != nil)
            || (caps.supportsAdaptiveNoiseCancelling && state.adaptiveNoiseCancelling != nil)
            || (caps.supportsAdaptiveSound && state.adaptiveSound != nil)
            || (caps.supportsDoubleConnection && state.doubleConnection != nil)
            || (caps.supportsAutoAnswer && state.autoAnswer != nil)
    }

    var body: some View {
        let state = model.state
        let caps = model.budsModel
        Card(title: tr("Extras")) {
            if caps.supportsFindDevice {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Find my earbuds")).font(.callout)
                    HStack(spacing: 8) {
                        if caps.supportsFindPerEarbud {
                            findButton(.left, title: tr("Left"))
                            findButton(.right, title: tr("Right"))
                        } else {
                            findButton(.both, title: tr("Find"))
                        }
                    }
                    Text(tr("Plays a loud sound. Remove the earbuds from your ears first."))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if caps.supportsWearingDetection, let value = state.wearingDetection {
                SettingToggle(title: tr("Wearing detection"), isOn: value, onChange: model.setWearingDetection)
            }
            if caps.supportsAdaptiveNoiseCancelling, let value = state.adaptiveNoiseCancelling {
                SettingToggle(title: tr("Adaptive noise cancelling"), isOn: value, onChange: model.setAdaptiveNoiseCancelling)
            }
            if caps.supportsAdaptiveSound, let value = state.adaptiveSound {
                SettingToggle(title: tr("Adaptive sound"), isOn: value, onChange: model.setAdaptiveSound)
            }
            if caps.supportsDoubleConnection, let value = state.doubleConnection {
                SettingToggle(title: tr("Dual device connection"), isOn: value, onChange: model.setDoubleConnection)
            }
            if caps.supportsAutoAnswer, let value = state.autoAnswer {
                SettingToggle(title: tr("Auto-answer calls"), isOn: value, onChange: model.setAutoAnswer)
            }
        }
    }

    private func findButton(_ target: FindTarget, title: String) -> some View {
        let active = model.findingTarget == target
        return Button {
            model.toggleFind(target)
        } label: {
            Label(active ? tr("Stop") : title, systemImage: active ? "stop.fill" : "speaker.wave.2.fill")
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(active ? Color.white : Color.primary)
                .background(active ? Color.red : Color.primary.opacity(0.08), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct GesturesCard: View {
    let model: BudsViewModel
    @State private var expanded = false

    var body: some View {
        Card {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(TapType.displayOrder.filter { model.budsModel.supports(tap: $0) }, id: \.self) { tap in
                        if let assignment = model.state.gestures.first(where: { $0.tap == tap }) {
                            row(tap: tap, assignment: assignment)
                        }
                    }
                    cycleSection
                }
                .padding(.top, 8)
            } label: {
                Text(tr("Gestures")).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            }
        }
    }

    private func row(tap: TapType, assignment: GestureAssignment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tap.title).font(.callout)
            HStack(spacing: 8) {
                picker(tap: tap, position: .left, code: assignment.left)
                picker(tap: tap, position: .right, code: assignment.right)
            }
        }
    }

    private func picker(tap: TapType, position: EarbudPosition, code: UInt8) -> some View {
        var options = model.budsModel.gestureActions(for: tap).map { (code: $0, title: tap.actionTitle(code: $0) ?? "") }
        if !options.contains(where: { $0.code == code }) {
            options.append((code, tr("Unknown (0x%02lX)", Int(code))))
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(position == .left ? tr("Left") : tr("Right")).font(.caption2).foregroundStyle(.secondary)
            Picker(tap.title, selection: Binding(
                get: { code }, set: { model.setGesture(tap: tap, position: position, action: $0) }
            )) {
                ForEach(options, id: \.code) { Text($0.title).tag($0.code) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var cycleSection: some View {
        let usesNoiseControl = model.state.gestures.first(where: { $0.tap == .long })
            .map { $0.left == LongGestureAction.ambientSoundControl.rawValue || $0.right == LongGestureAction.ambientSoundControl.rawValue } ?? false
        if usesNoiseControl, !model.budsModel.ambientSoundCycles.isEmpty, let cycle = model.state.ambientSoundCycle {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Long press cycles through")).font(.callout)
                HStack(spacing: 8) {
                    cyclePicker(position: .left, value: cycle.left)
                    cyclePicker(position: .right, value: cycle.right)
                }
            }
        }
    }

    private func cyclePicker(position: EarbudPosition, value: AmbientSoundCycle?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(position == .left ? tr("Left") : tr("Right")).font(.caption2).foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { value }, set: { if let cycle = $0 { model.setAmbientSoundCycle(position: position, cycle: cycle) } }
            )) {
                if value == nil { Text("-").tag(AmbientSoundCycle?.none) }
                ForEach(model.budsModel.ambientSoundCycles, id: \.self) { Text($0.title).tag(AmbientSoundCycle?.some($0)) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SettingsCard: View {
    let model: BudsViewModel
    @AppStorage("showBatteryInMenuBar") private var showBattery = true
    @AppStorage(BudsViewModel.lowBatteryDefaultsKey) private var lowBattery = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @Bindable private var localizer = Localizer.shared

    var body: some View {
        Card(title: tr("Settings")) {
            if model.pairedDevices.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Device")).font(.callout)
                    Picker(tr("Device"), selection: Binding(
                        get: { model.selectedDeviceID ?? "" }, set: { model.selectDevice($0) }
                    )) {
                        ForEach(model.pairedDevices, id: \.id) { Text(verbatim: $0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Language")).font(.callout)
                Picker(tr("Language"), selection: $localizer.choice) {
                    ForEach(Localizer.Choice.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            SettingToggle(title: tr("Show battery in menu bar"), isOn: showBattery) { showBattery = $0 }
            SettingToggle(title: tr("Low battery notification (below 15%)"), isOn: lowBattery) { lowBattery = $0 }
            SettingToggle(title: tr("Launch at login"), isOn: launchAtLogin) { newValue in
                LaunchAtLogin.setEnabled(newValue)
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }
}

struct FooterView: View {
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            Button {
                withAnimation(.smooth(duration: 0.25)) { showSettings.toggle() }
            } label: {
                Label(tr("Settings"), systemImage: "gearshape")
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(tr("Quit"), systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }
}
