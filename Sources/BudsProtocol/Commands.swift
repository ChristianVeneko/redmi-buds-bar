/// Commands the phone can send to the earbuds.
public enum Command: Equatable, Sendable {
    case requestDeviceInfo
    case requestRunInfo
    case requestConfig([ConfigCode])
    case setNoiseMode(AmbientSoundMode)
    case setNoiseCancellingStrength(NoiseCancellingStrength)
    case setTransparencyStrength(TransparencyStrength)
    case setEqualizerPreset(EqualizerPreset)
    case setBoolean(BooleanSetting, Bool)
    /// Note: the wire flag is inverted (0x00 = enabled).
    case setWearingDetection(Bool)
    /// `action` is a raw code: see `GestureAction` / `LongGestureAction`.
    case setGesture(tap: TapType, position: EarbudPosition, action: UInt8)
    case setAmbientSoundCycle(position: EarbudPosition, cycle: AmbientSoundCycle)
    /// Writes the custom equalizer curve. The preset must also be switched to `.custom`.
    case setCustomEqualizer(EqualizerCurve)
    /// Makes the earbuds play a locating sound (stop is sent first, like Gadgetbridge).
    case startFindEarbuds(FindTarget)
    case stopFindEarbuds
}

/// Encodes commands into frames and owns the phone-side sequence counter.
public struct CommandBuilder: Sendable {
    public private(set) var sequence: UInt8

    public init(sequence: UInt8 = 0) {
        self.sequence = sequence
    }

    public mutating func nextSequence() -> UInt8 {
        defer { sequence &+= 1 }
        return sequence
    }

    public mutating func message(_ opcode: Opcode, payload: [UInt8]) -> Message {
        Message(type: .phoneRequest, opcode: opcode, sequence: nextSequence(), payload: payload)
    }

    /// Returns the concatenated frames for the command.
    public mutating func encode(_ command: Command) -> [UInt8] {
        frames(command).flatMap { $0 }
    }

    /// Returns one frame per message to send.
    public mutating func frames(_ command: Command) -> [[UInt8]] {
        switch command {
        case .requestDeviceInfo:
            return [message(.getDeviceInfo, payload: [0xFF, 0xFF, 0xFF, 0xFF]).encode()]
        case .requestRunInfo:
            return [message(.getDeviceRunInfo, payload: [0xFF, 0xFF, 0xFF, 0xFF]).encode()]
        case .requestConfig(let codes):
            return codes.map { message(.getConfig, payload: [0x00, $0.rawValue]).encode() }
        case .setNoiseMode(let mode):
            return [message(.anc, payload: [0x02, 0x04, mode.rawValue]).encode()]
        case .setNoiseCancellingStrength(let strength):
            return [message(.setConfig, payload: [0x04, 0x00, 0x0B, 0x01, strength.rawValue]).encode()]
        case .setTransparencyStrength(let strength):
            return [message(.setConfig, payload: [0x04, 0x00, 0x0B, 0x02, strength.rawValue]).encode()]
        case .setEqualizerPreset(let preset):
            return [message(.setConfig, payload: [0x03, 0x00, ConfigCode.equalizerPreset.rawValue, preset.rawValue]).encode()]
        case .setBoolean(let setting, let value):
            return [message(.setConfig, payload: [0x03, 0x00, setting.rawValue, value ? 0x01 : 0x00]).encode()]
        case .setWearingDetection(let enabled):
            return [message(.anc, payload: [0x02, 0x06, enabled ? 0x00 : 0x01]).encode()]
        case .setGesture(let tap, let position, let action):
            var payload: [UInt8] = [0x05, 0x00, 0x02, tap.rawValue, 0xFF, 0xFF]
            payload[position == .left ? 4 : 5] = action
            return [message(.setConfig, payload: payload).encode()]
        case .setAmbientSoundCycle(let position, let cycle):
            var payload: [UInt8] = [0x04, 0x00, 0x0A, 0xFF, 0xFF]
            payload[position == .left ? 3 : 4] = cycle.rawValue
            return [message(.setConfig, payload: payload).encode()]
        case .setCustomEqualizer(let curve):
            return [message(.setConfig, payload: curve.encodePayload()).encode()]
        case .startFindEarbuds(let target):
            return [
                message(.setConfig, payload: Self.findPayload(start: false, target: .both)).encode(),
                message(.setConfig, payload: Self.findPayload(start: true, target: target)).encode(),
            ]
        case .stopFindEarbuds:
            return [message(.setConfig, payload: Self.findPayload(start: false, target: .both)).encode()]
        }
    }

    private static func findPayload(start: Bool, target: FindTarget) -> [UInt8] {
        [0x04, 0x00, 0x09, start ? 0x01 : 0x00, target.rawValue]
    }
}
