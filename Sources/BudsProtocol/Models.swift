/// Active noise control mode of the earbuds.
public enum AmbientSoundMode: UInt8, CaseIterable, Sendable {
    case off = 0x00
    case noiseCancelling = 0x01
    case transparency = 0x02
}

public enum NoiseCancellingStrength: UInt8, CaseIterable, Sendable {
    case balanced = 0x00
    case light = 0x01
    case deep = 0x02
    case adaptive = 0x03
}

public enum TransparencyStrength: UInt8, CaseIterable, Sendable {
    case regular = 0x00
    case voice = 0x01
    case ambient = 0x02
}

public enum EqualizerPreset: UInt8, CaseIterable, Sendable {
    case standard = 0x00
    case balanced = 0x15
    case treble = 0x06
    case bass = 0x05
    case voice = 0x01
    case volume = 0x07
    case custom = 0x0A
}

public enum EarbudPosition: Int, CaseIterable, Sendable {
    case left = 0
    case right = 1
}

public enum TapType: UInt8, CaseIterable, Sendable {
    case single = 0x04
    case double = 0x01
    case triple = 0x02
    case long = 0x03
}

/// Actions for single/double/triple taps.
public enum GestureAction: UInt8, CaseIterable, Sendable {
    case none = 0x08
    case playPause = 0x01
    case previousTrack = 0x02
    case nextTrack = 0x03
    case volumeUp = 0x04
    case volumeDown = 0x05
}

/// Actions for the long press gesture.
public enum LongGestureAction: UInt8, CaseIterable, Sendable {
    case none = 0x08
    case voiceAssistant = 0x00
    case ambientSoundControl = 0x06
}

/// Which noise modes a long press cycles through.
public enum AmbientSoundCycle: UInt8, CaseIterable, Sendable {
    case noiseCancellingOff = 0x03
    case transparencyOff = 0x05
    case noiseCancellingTransparency = 0x06
    case all = 0x07
}

/// Boolean settings written with `SET_CONFIG`.
public enum BooleanSetting: UInt8, Sendable {
    case autoAnswer = 0x03
    case doubleConnection = 0x04
    case adaptiveNoiseCancelling = 0x25
    case adaptiveSound = 0x29
}

/// Identifiers used by `GET_CONFIG` / `SET_CONFIG` / `NOTIFY_CONFIG`.
public enum ConfigCode: UInt8, CaseIterable, Sendable {
    case gestures = 0x02
    case autoAnswer = 0x03
    case doubleConnection = 0x04
    case earDetection = 0x06
    case equalizerPreset = 0x07
    case longGestures = 0x0A
    case effectStrength = 0x0B
    case earbudsPosition = 0x0C
    case adaptiveNoiseCancelling = 0x25
    case adaptiveSound = 0x29
    case equalizerCurve = 0x37
    case customizedNoiseCancelling = 0x3B

    /// Requested right after authentication, in the same order as Gadgetbridge.
    public static let initialRequests: [ConfigCode] = [
        .effectStrength, .adaptiveNoiseCancelling, .gestures, .longGestures, .earDetection,
        .doubleConnection, .autoAnswer, .adaptiveSound, .equalizerPreset, .equalizerCurve,
    ]
}

public struct BatteryLevel: Equatable, Sendable {
    public var percent: Int
    public var isCharging: Bool

    public init(percent: Int, isCharging: Bool) {
        self.percent = percent
        self.isCharging = isCharging
    }

    /// Bit 7 is the charging flag, bits 0-6 the percentage. 0xFF means "unknown".
    public init?(raw: UInt8) {
        guard raw != 0xFF else { return nil }
        self.init(percent: Int(raw & 0x7F), isCharging: raw & 0x80 != 0)
    }
}

public struct BatteryStatus: Equatable, Sendable {
    public var left: BatteryLevel?
    public var right: BatteryLevel?
    public var `case`: BatteryLevel?

    public init(left: BatteryLevel? = nil, right: BatteryLevel? = nil, case: BatteryLevel? = nil) {
        self.left = left
        self.right = right
        self.case = `case`
    }

    /// Wire order is left, right, case.
    init(bytes: ArraySlice<UInt8>) {
        let b = Array(bytes)
        self.init(
            left: b.count > 0 ? BatteryLevel(raw: b[0]) : nil,
            right: b.count > 1 ? BatteryLevel(raw: b[1]) : nil,
            case: b.count > 2 ? BatteryLevel(raw: b[2]) : nil
        )
    }
}

public struct GestureAssignment: Equatable, Sendable {
    public var tap: TapType
    public var left: UInt8
    public var right: UInt8

    public init(tap: TapType, left: UInt8, right: UInt8) {
        self.tap = tap
        self.left = left
        self.right = right
    }
}

/// Wear/case flags of the earbuds (config 0x0C). Bit meaning is inferred from Gadgetbridge's comment
/// ("wearing left, wearing right, left in case, right in case") and a capture taken while charging in the case.
public struct EarbudsPositionFlags: Equatable, Sendable {
    public var rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public var leftWorn: Bool { rawValue & 0x01 != 0 }
    public var rightWorn: Bool { rawValue & 0x02 != 0 }
    public var leftInCase: Bool { rawValue & 0x04 != 0 }
    public var rightInCase: Bool { rawValue & 0x08 != 0 }
}

public enum FindTarget: UInt8, CaseIterable, Sendable {
    case left = 0x01
    case right = 0x02
    case both = 0x03
}
