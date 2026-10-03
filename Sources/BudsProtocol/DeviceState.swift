/// Aggregated, UI-facing state derived from protocol events. Battery reports replace the previous values
/// (a missing level means "not reported"); other unknown values never overwrite known ones.
public struct DeviceState: Equatable, Sendable {
    public var name: String?
    public var firmware: String?
    public var hardware: String?
    public var battery = BatteryStatus()
    public var noiseMode: AmbientSoundMode?
    public var noiseCancellingStrength: NoiseCancellingStrength?
    public var transparencyStrength: TransparencyStrength?
    public var equalizerPreset: EqualizerPreset?
    public var adaptiveNoiseCancelling: Bool?
    public var adaptiveSound: Bool?
    public var autoAnswer: Bool?
    public var doubleConnection: Bool?
    public var wearingDetection: Bool?
    public var equalizerCurve: EqualizerCurve?
    public var position: EarbudsPositionFlags?
    public var gestures: [GestureAssignment] = []
    public var ambientSoundCycle: (left: AmbientSoundCycle?, right: AmbientSoundCycle?)?

    public init() {}


    public mutating func apply(_ event: BudsEvent) {
        switch event {
        case .deviceInfo(let info):
            name = info.name ?? name
            firmware = info.firmware ?? firmware
            hardware = info.hardware ?? hardware
            battery = info.battery
        case .runInfo(let info):
            if let mode = info.noiseMode { noiseMode = mode }
            if let enabled = info.wearingDetectionEnabled { wearingDetection = enabled }
        case .status(let updates):
            for update in updates {
                switch update {
                case .battery(let status): battery = status
                case .noiseMode(let mode): if let mode { noiseMode = mode }
                case .unknown: break
                }
            }
        case .config(let updates):
            for update in updates { apply(update) }
        case .authenticated, .commandAcknowledged, .unhandled:
            break
        }
    }

    private mutating func apply(_ update: ConfigUpdate) {
        switch update {
        case .gestures(let value): gestures = value
        case .ambientSoundCycle(let left, let right): ambientSoundCycle = (left, right)
        case .autoAnswer(let value): autoAnswer = value
        case .doubleConnection(let value): doubleConnection = value
        case .adaptiveNoiseCancelling(let value): adaptiveNoiseCancelling = value
        case .adaptiveSound(let value): adaptiveSound = value
        case .equalizerPreset(let value): if let value { equalizerPreset = value }
        case .noiseCancellingStrength(let value): if let value { noiseCancellingStrength = value }
        case .transparencyStrength(let value): if let value { transparencyStrength = value }
        case .noiseModeChanged(let mode, let strength):
            guard let mode else { return }
            noiseMode = mode
            switch mode {
            case .noiseCancelling: noiseCancellingStrength = NoiseCancellingStrength(rawValue: strength) ?? noiseCancellingStrength
            case .transparency: transparencyStrength = TransparencyStrength(rawValue: strength) ?? transparencyStrength
            case .off: break
            }
        case .equalizerCurve(let levels):
            if let curve = EqualizerCurve(levelCodes: levels) { equalizerCurve = curve }
        case .earbudsPosition(let flags): position = flags
        case .wearingDetection(let value): wearingDetection = value
        case .unknown:
            break
        }
    }
}

extension DeviceState {
    public static func == (lhs: DeviceState, rhs: DeviceState) -> Bool {
        lhs.name == rhs.name && lhs.firmware == rhs.firmware && lhs.hardware == rhs.hardware
            && lhs.battery == rhs.battery && lhs.noiseMode == rhs.noiseMode
            && lhs.noiseCancellingStrength == rhs.noiseCancellingStrength
            && lhs.transparencyStrength == rhs.transparencyStrength
            && lhs.equalizerPreset == rhs.equalizerPreset
            && lhs.adaptiveNoiseCancelling == rhs.adaptiveNoiseCancelling
            && lhs.adaptiveSound == rhs.adaptiveSound && lhs.autoAnswer == rhs.autoAnswer
            && lhs.doubleConnection == rhs.doubleConnection && lhs.wearingDetection == rhs.wearingDetection
            && lhs.gestures == rhs.gestures && lhs.equalizerCurve == rhs.equalizerCurve
            && lhs.position == rhs.position
            && lhs.ambientSoundCycle?.left == rhs.ambientSoundCycle?.left
            && lhs.ambientSoundCycle?.right == rhs.ambientSoundCycle?.right
    }
}
