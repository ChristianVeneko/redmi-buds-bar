import BudsProtocol
import SwiftUI

/// Sections of the connected panel, shown one at a time through the tab bar.
enum PanelTab: String, CaseIterable {
    case noise, equalizer, extras, gestures, settings

    var symbol: String {
        switch self {
        case .noise: "waveform"
        case .equalizer: "slider.vertical.3"
        case .extras: "sparkles"
        case .gestures: "hand.tap"
        case .settings: "gearshape"
        }
    }

    var title: String {
        switch self {
        case .noise: tr("Noise control")
        case .equalizer: tr("Equalizer")
        case .extras: tr("Extras")
        case .gestures: tr("Gestures")
        case .settings: tr("Settings")
        }
    }
}

/// Root of the menu bar panel. Its ideal size drives the size of the hosting window.
struct PanelView: View {
    @Bindable var model: BudsViewModel
    @AppStorage("selectedPanelTab") private var storedTab = PanelTab.noise.rawValue
    @State private var showSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let localizer = Localizer.shared

    private var availableTabs: [PanelTab] {
        let caps = model.budsModel
        var tabs: [PanelTab] = []
        if caps.hasNoiseControl { tabs.append(.noise) }
        if caps.hasEqualizer { tabs.append(.equalizer) }
        if ExtrasCard.hasContent(model) { tabs.append(.extras) }
        if caps.hasGestures, !model.state.gestures.isEmpty { tabs.append(.gestures) }
        tabs.append(.settings)
        return tabs
    }

    private var currentTab: PanelTab {
        let tabs = availableTabs
        if let stored = PanelTab(rawValue: storedTab), tabs.contains(stored) { return stored }
        return tabs.first ?? .settings
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollIndicators(.hidden)
                .frame(height: Theme.maxPanelHeight)
        }
        .frame(width: Theme.panelWidth)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: model.connection)
        .environment(\.locale, localizer.locale)
        .tint(Theme.accent)
    }

    private var content: some View {
        VStack(spacing: 12) {
            HeaderView(model: model)
            if model.connection == .connected {
                let caps = model.budsModel
                BatteryCard(battery: model.state.battery, position: model.state.position)
                TabBar(tabs: availableTabs, selection: currentTab) { select($0) }
                tabContent(currentTab)
                if !caps.isTestedOnHardware {
                    Text(tr("Support for this model has not been tested on hardware."))
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            } else {
                OfflineCard(model: model)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                if showSettings {
                    SettingsCard(model: model)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                }
            }
            FooterView(isSettingsActive: model.connection == .connected ? currentTab == .settings : showSettings) {
                toggleSettings()
            }
        }
        .padding(12)
    }

    @ViewBuilder private func tabContent(_ tab: PanelTab) -> some View {
        // A ZStack hosts the transition so the outgoing and incoming sections crossfade in place.
        ZStack(alignment: .top) {
            Group {
                switch tab {
                case .noise: NoiseCard(model: model)
                case .equalizer: EqualizerCard(model: model)
                case .extras: ExtrasCard(model: model)
                case .gestures: GesturesCard(model: model)
                case .settings: SettingsCard(model: model)
                }
            }
            .id(tab)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)),
                removal: .opacity))
        }
    }

    private func select(_ tab: PanelTab) {
        withAnimation(Theme.select(reduceMotion)) { storedTab = tab.rawValue }
    }

    private func toggleSettings() {
        if model.connection == .connected {
            if currentTab == .settings {
                select(availableTabs.first ?? .settings)
            } else {
                select(.settings)
            }
        } else {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { showSettings.toggle() }
        }
    }
}

/// Icon tab bar with a sliding selection indicator.
struct TabBar: View {
    let tabs: [PanelTab]
    let selection: PanelTab
    let onSelect: (PanelTab) -> Void
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = tab == selection
                Button { onSelect(tab) } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.selectedFill)
                                    .matchedGeometryEffect(id: "tabSelection", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.92))
                .help(tab.title)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
                .font(.system(size: 17))
                .foregroundStyle(.primary.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(Theme.controlFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: model.state.name ?? model.deviceName).font(.headline)
                HStack(spacing: 5) {
                    StatusDot(color: dotColor, pulsing: model.connection == .connecting)
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
            }
            Spacer()
            Button {
                model.refreshOrReconnect()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Theme.controlFill, in: Circle())
            }
            .buttonStyle(PressScaleStyle())
            .help(model.connection == .connected ? tr("Refresh") : tr("Reconnect"))
        }
        .padding(.horizontal, 2)
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
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let state = model.state
        let caps = model.budsModel
        Card(title: tr("Noise control")) {
            HStack(spacing: 8) {
                ForEach(model.budsModel.ambientSoundModes, id: \.self) { mode in
                    ModeTile(title: mode.title, symbol: mode.symbol, isSelected: state.noiseMode == mode, namespace: namespace) {
                        withAnimation(Theme.select(reduceMotion)) { model.setNoiseMode(mode) }
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
            SegmentedControl(options: options, selection: selection, title: { $0[keyPath: label] }, onSelect: set)
        }
    }
}

struct EqualizerCard: View {
    let model: BudsViewModel
    @Namespace private var namespace
    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 6)]

    var body: some View {
        let state = model.state
        let caps = model.budsModel
        Card(title: tr("Equalizer")) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(caps.equalizerPresets.filter { $0 != .custom }, id: \.self) { preset in
                    Chip(title: preset.title, isSelected: state.equalizerPreset == preset, namespace: namespace) {
                        withAnimation(.snappy(duration: 0.25)) { model.setEqualizerPreset(preset) }
                    }
                }
                if caps.supportsCustomEqualizer {
                    ForEach(CustomEqualizerPreset.allCases, id: \.self) { preset in
                        Chip(title: preset.title, isSelected: model.activeCustomPreset == preset, namespace: namespace) {
                            withAnimation(.snappy(duration: 0.25)) { model.applyCustomPreset(preset) }
                        }
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
                .foregroundStyle(active ? Color.white : Color.primary.opacity(0.85))
                .background(active ? Color.red.opacity(0.85) : Theme.controlFill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct GesturesCard: View {
    let model: BudsViewModel

    var body: some View {
        Card(title: tr("Gestures")) {
            ForEach(TapType.displayOrder.filter { model.budsModel.supports(tap: $0) }, id: \.self) { tap in
                if let assignment = model.state.gestures.first(where: { $0.tap == tap }) {
                    row(tap: tap, assignment: assignment)
                }
            }
            cycleSection
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
                SegmentedControl(
                    options: Localizer.Choice.allCases, selection: localizer.choice, title: { $0.title },
                    onSelect: { localizer.choice = $0 })
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
    let isSettingsActive: Bool
    let toggleSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            footerButton(title: tr("Settings"), symbol: "gearshape", isActive: isSettingsActive, action: toggleSettings)
            footerButton(title: tr("Quit"), symbol: "power", isActive: false) { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private func footerButton(title: String, symbol: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout)
                .foregroundStyle(isActive ? Theme.accent : Color.primary.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isActive ? Theme.selectedFill : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }
}
