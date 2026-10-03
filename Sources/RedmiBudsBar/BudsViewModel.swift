import BudsProtocol
import Foundation
import IOBluetooth
import Observation
@preconcurrency import UserNotifications

@MainActor
@Observable
final class BudsViewModel {
    enum Connection: Equatable {
        case deviceNotFound
        case disconnected
        case connecting
        case connected
    }

    private(set) var connection: Connection = .deviceNotFound
    private(set) var state = DeviceState()
    private(set) var lastError: String?
    private(set) var deviceName = "REDMI Buds"
    /// All paired REDMI Buds devices (the Settings picker appears when there is more than one).
    private(set) var pairedDevices: [DeviceCandidate] = []
    private(set) var selectedDeviceID: String?
    /// Earbud currently playing the locating sound, if any.
    private(set) var findingTarget: FindTarget?

    static let selectedDeviceKey = "selectedDeviceAddress"

    /// Capabilities of the model resolved from the device name (the name reported by the earbuds wins).
    var budsModel: BudsModel { BudsModel.resolve(name: state.name ?? deviceName) }

    private let transport = RFCOMMTransport()
    private var session = BudsSession()
    private var retryTimer: Timer?
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotification: IOBluetoothUserNotification?
    private var observer: NotificationBridge?
    private var lowBatteryMonitor = LowBatteryMonitor(threshold: 15)

    init() {
        transport.onEvent = { [weak self] event in
            onMain { self?.handle(event) }
        }
        observer = NotificationBridge { [weak self] in
            onMain { self?.deviceDidConnect() }
        } onDisconnect: { [weak self] in
            onMain { self?.deviceDidDisconnect() }
        }
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: observer, selector: #selector(NotificationBridge.deviceConnected(_:device:)))
        retryTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            onMain { self?.retryIfNeeded() }
        }
        attemptConnection(force: false)
    }

    // MARK: Connection management

    /// Manual "Reconnect": drops the current channel (if any) and tries again regardless of ACL state.
    func reconnect() {
        Log.app.info("Manual reconnect requested")
        transport.disconnect()
        session = BudsSession()
        connection = .disconnected
        attemptConnection(force: true)
    }

    /// Switches to another paired device (Settings picker).
    func selectDevice(_ id: String) {
        guard id != selectedDeviceID else { return }
        UserDefaults.standard.set(id, forKey: Self.selectedDeviceKey)
        transport.disconnect()
        if let notification = disconnectNotification { notification.unregister() }
        disconnectNotification = nil
        state = DeviceState()
        findingTarget = nil
        connection = .disconnected
        attemptConnection(force: true)
    }

    private func retryIfNeeded() {
        guard connection != .connected, connection != .connecting else { return }
        attemptConnection(force: false)
    }

    private func deviceDidConnect() {
        Log.app.info("Bluetooth device connected notification")
        guard connection != .connected, connection != .connecting else { return }
        // Give the earbuds a moment to bring up their services before opening the control channel.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            MainActor.assumeIsolated { self?.attemptConnection(force: false) }
        }
    }

    private func deviceDidDisconnect() {
        Log.app.info("Bluetooth device disconnected notification")
        if let device = transport.device, !device.isConnected() {
            transport.disconnect()
            connection = .disconnected
            findingTarget = nil
        }
    }

    private func attemptConnection(force: Bool) {
        guard connection != .connected, connection != .connecting else { return }
        let paired = RFCOMMTransport.pairedBuds()
        pairedDevices = paired.map(\.candidate)
        let preferred = UserDefaults.standard.string(forKey: Self.selectedDeviceKey)
        guard let choice = DeviceSelection.choose(from: pairedDevices, preferredID: preferred),
              let device = paired.first(where: { $0.candidate.id == choice.id })?.device else {
            connection = .deviceNotFound
            return
        }
        selectedDeviceID = choice.id
        deviceName = device.name ?? deviceName
        observeDisconnect(of: device)
        guard force || device.isConnected() else {
            connection = .disconnected
            return
        }
        connection = .connecting
        lastError = nil
        session = BudsSession()
        transport.connect(to: device)
    }

    private func observeDisconnect(of device: IOBluetoothDevice) {
        guard disconnectNotification == nil, let observer else { return }
        disconnectNotification = device.register(
            forDisconnectNotification: observer, selector: #selector(NotificationBridge.deviceDisconnected(_:device:)))
    }

    private func handle(_ event: RFCOMMTransport.Event) {
        switch event {
        case .opened:
            // Connected at the transport level; the protocol handshake starts now.
            for frame in session.begin() { send(frame) }
        case .data(let bytes):
            Log.protocolLog.debug("RX \(bytes.hexString, privacy: .public)")
            let output = session.receive(bytes)
            for frame in output.outgoing { send(frame) }
            for event in output.events { apply(event) }
        case .closed:
            connection = .disconnected
            findingTarget = nil
        case .failed(let message):
            lastError = message
            connection = .disconnected
        }
    }

    private func apply(_ event: BudsEvent) {
        switch event {
        case .authenticated:
            connection = .connected
            Log.protocolLog.info("Authenticated")
        case .unhandled(let message):
            Log.protocolLog.notice("Unhandled frame: \(message.encode().hexString, privacy: .public)")
        case .status(let updates):
            for case .unknown(let index, let data) in updates {
                Log.protocolLog.notice("Unknown status entry \(index): \(data.hexString, privacy: .public)")
            }
        case .config(let updates):
            for case .unknown(let code, let data) in updates {
                Log.protocolLog.notice("Unknown config \(code): \(data.hexString, privacy: .public)")
            }
        case .commandAcknowledged(let opcode):
            Log.protocolLog.debug("Command acknowledged: \(opcode.code)")
        case .deviceInfo, .runInfo:
            break
        }
        state.apply(event)
        if case .deviceInfo = event, connection != .connected { connection = .connected }
        if case .config(let updates) = event {
            for case .earbudsPosition(let flags) in updates {
                Log.protocolLog.info("Earbuds position flags: \(flags.rawValue, format: .hex)")
            }
        }
        if case .status = event { checkLowBattery() }
        if case .deviceInfo = event { checkLowBattery() }
    }

    // MARK: Low battery notification

    static let lowBatteryDefaultsKey = "lowBatteryNotifications"

    private var lowBatteryNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.lowBatteryDefaultsKey) as? Bool ?? true
    }

    private func checkLowBattery() {
        let low = lowBatteryMonitor.update(state.battery)
        guard lowBatteryNotificationsEnabled, !low.isEmpty else { return }
        for position in low {
            let level = (position == .left ? state.battery.left : state.battery.right)?.percent ?? 0
            let side = position == .left ? tr("Left") : tr("Right")
            notify(title: tr("Low battery"), body: tr("%@ earbud is at %d%%.", side, level))
        }
    }

    private func notify(title: String, body: String) {
        // UNUserNotificationCenter requires a bundled app.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    private func send(_ frame: [UInt8]) {
        Log.protocolLog.debug("TX \(frame.hexString, privacy: .public)")
        if !transport.write(frame) {
            Log.protocolLog.error("Dropped frame (channel not writable)")
        }
    }

    private func run(_ command: Command) {
        guard connection == .connected else { return }
        for frame in session.send(command) { send(frame) }
    }

    // MARK: User actions (optimistic local update, then confirmation from the earbuds)

    func setNoiseMode(_ mode: AmbientSoundMode) {
        state.noiseMode = mode
        run(.setNoiseMode(mode))
    }

    func setNoiseCancellingStrength(_ value: NoiseCancellingStrength) {
        state.noiseCancellingStrength = value
        run(.setNoiseCancellingStrength(value))
    }

    func setTransparencyStrength(_ value: TransparencyStrength) {
        state.transparencyStrength = value
        run(.setTransparencyStrength(value))
    }

    func setEqualizerPreset(_ value: EqualizerPreset) {
        state.equalizerPreset = value
        run(.setEqualizerPreset(value))
    }

    func setAdaptiveNoiseCancelling(_ on: Bool) {
        state.adaptiveNoiseCancelling = on
        run(.setBoolean(.adaptiveNoiseCancelling, on))
    }

    func setAdaptiveSound(_ on: Bool) {
        state.adaptiveSound = on
        run(.setBoolean(.adaptiveSound, on))
    }

    func setAutoAnswer(_ on: Bool) {
        state.autoAnswer = on
        run(.setBoolean(.autoAnswer, on))
    }

    func setDoubleConnection(_ on: Bool) {
        state.doubleConnection = on
        run(.setBoolean(.doubleConnection, on))
    }

    func setWearingDetection(_ on: Bool) {
        state.wearingDetection = on
        run(.setWearingDetection(on))
    }

    func setGesture(tap: TapType, position: EarbudPosition, action: UInt8) {
        if let index = state.gestures.firstIndex(where: { $0.tap == tap }) {
            if position == .left { state.gestures[index].left = action } else { state.gestures[index].right = action }
        }
        run(.setGesture(tap: tap, position: position, action: action))
    }

    func setAmbientSoundCycle(position: EarbudPosition, cycle: AmbientSoundCycle) {
        let current = state.ambientSoundCycle
        state.ambientSoundCycle = (position == .left ? cycle : current?.left, position == .right ? cycle : current?.right)
        run(.setAmbientSoundCycle(position: position, cycle: cycle))
    }

    /// App-defined preset: switch the firmware to its custom slot, then write the curve.
    /// The order (preset first, curve second) is an assumption; Gadgetbridge sends the two independently.
    func applyCustomPreset(_ preset: CustomEqualizerPreset) {
        state.equalizerPreset = .custom
        state.equalizerCurve = preset.curve
        run(.setEqualizerPreset(.custom))
        run(.setCustomEqualizer(preset.curve))
    }

    /// The app-defined preset matching the curve currently active on the earbuds.
    var activeCustomPreset: CustomEqualizerPreset? {
        guard state.equalizerPreset == .custom, let curve = state.equalizerCurve else { return nil }
        return CustomEqualizerPreset.matching(curve)
    }

    func toggleFind(_ target: FindTarget) {
        guard connection == .connected else { return }
        if findingTarget == target {
            findingTarget = nil
            run(.stopFindEarbuds)
        } else {
            findingTarget = target
            run(.startFindEarbuds(target))
        }
    }

    /// Reconnects when offline, otherwise requests a fresh snapshot.
    func refreshOrReconnect() {
        if connection == .connected { refresh() } else { reconnect() }
    }

    /// Requests a fresh snapshot, e.g. when the menu opens.
    func refresh() {
        run(.requestDeviceInfo)
        run(.requestRunInfo)
        run(.requestConfig(ConfigCode.initialRequests))
    }
}

/// Objective-C target for IOBluetooth user notifications (selector based API).
final class NotificationBridge: NSObject {
    private let onConnect: () -> Void
    private let onDisconnect: () -> Void

    init(onConnect: @escaping () -> Void, onDisconnect: @escaping () -> Void) {
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
    }

    @objc func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if BudsModel.isRedmiBuds(name: device.name) { onConnect() }
    }

    @objc func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if BudsModel.isRedmiBuds(name: device.name) { onDisconnect() }
    }
}

/// Runs `work` on the main actor. IOBluetooth may deliver notifications and channel callbacks on
/// a background thread, so callbacks hop to the main queue (FIFO, preserving event order) when needed.
func onMain(_ work: @escaping @MainActor () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated(work)
    } else {
        DispatchQueue.main.async { MainActor.assumeIsolated(work) }
    }
}
