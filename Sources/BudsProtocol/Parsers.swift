/// `len | index | data...` entries where `len` counts the index byte and the data.
func parseTLV(_ payload: [UInt8]) -> [(index: UInt8, data: [UInt8])] {
    var entries: [(UInt8, [UInt8])] = []
    var i = 0
    while i + 1 < payload.count {
        let length = Int(payload[i])
        guard length >= 1, i + 1 + length <= payload.count else { break }
        entries.append((payload[i + 1], Array(payload[(i + 2)..<(i + 1 + length)])))
        i += length + 1
    }
    return entries
}

public struct DeviceInfo: Equatable, Sendable {
    public var name: String?
    public var firmware: String?
    public var secondaryFirmware: String?
    public var hardware: String?
    public var battery = BatteryStatus()

    public init() {}

    private static func version(_ a: UInt8, _ b: UInt8) -> String {
        "\(a >> 4).\(a & 0xF).\(b >> 4).\(b & 0xF)"
    }

    /// Decodes the `GET_DEVICE_INFO` response payload.
    public static func parse(_ payload: [UInt8]) -> DeviceInfo {
        var info = DeviceInfo()
        for (index, data) in parseTLV(payload) {
            switch index {
            case 0x00:
                info.name = String(decoding: data, as: UTF8.self)
            case 0x01 where data.count >= 4:
                info.firmware = version(data[0], data[1])
                info.secondaryFirmware = version(data[2], data[3])
            case 0x03 where data.count >= 4:
                func h(_ b: UInt8) -> String { Hex.string([b]).uppercased() }
                info.hardware = "VID: 0x\(h(data[0]))\(h(data[1])), PID: 0x\(h(data[2]))\(h(data[3]))"
            case 0x07:
                info.battery = BatteryStatus(bytes: data[...])
            default:
                break
            }
        }
        return info
    }
}

/// Unsolicited or periodic `REPORT_STATUS` entries.
public enum StatusUpdate: Equatable, Sendable {
    case battery(BatteryStatus)
    case noiseMode(AmbientSoundMode?)
    case unknown(index: UInt8, data: [UInt8])

    public static func parse(_ payload: [UInt8]) -> [StatusUpdate] {
        parseTLV(payload).map { index, data in
            switch index {
            case 0x00 where data.count >= 3:
                return .battery(BatteryStatus(bytes: data[...]))
            case 0x04 where data.count >= 1:
                return .noiseMode(AmbientSoundMode(rawValue: data[0]))
            default:
                return .unknown(index: index, data: data)
            }
        }
    }
}

/// Entries of the `GET_DEVICE_RUN_INFO` response.
public struct RunInfo: Equatable, Sendable {
    public var noiseMode: AmbientSoundMode?
    public var wearingDetectionEnabled: Bool?

    public init(noiseMode: AmbientSoundMode? = nil, wearingDetectionEnabled: Bool? = nil) {
        self.noiseMode = noiseMode
        self.wearingDetectionEnabled = wearingDetectionEnabled
    }

    public static func parse(_ payload: [UInt8]) -> RunInfo {
        var info = RunInfo()
        for (index, data) in parseTLV(payload) {
            guard let value = data.first else { continue }
            switch index {
            case 0x09: info.noiseMode = AmbientSoundMode(rawValue: value)
            case 0x0A: info.wearingDetectionEnabled = value == 0x00 // inverted flag on the wire
            default: break
            }
        }
        return info
    }
}

/// Entries of `GET_CONFIG` responses and `NOTIFY_CONFIG` notifications: `len | 00 | code | data...`.
public enum ConfigUpdate: Equatable, Sendable {
    case gestures([GestureAssignment])
    case ambientSoundCycle(left: AmbientSoundCycle?, right: AmbientSoundCycle?)
    case autoAnswer(Bool)
    case doubleConnection(Bool)
    case adaptiveNoiseCancelling(Bool)
    case adaptiveSound(Bool)
    case equalizerPreset(EqualizerPreset?)
    case noiseCancellingStrength(NoiseCancellingStrength?)
    case transparencyStrength(TransparencyStrength?)
    /// Notification: the active mode changed; `strength` applies to noise cancelling / transparency.
    case noiseModeChanged(mode: AmbientSoundMode?, strength: UInt8)
    /// Raw band levels of the custom equalizer curve.
    case equalizerCurve(levels: [UInt8])
    case earbudsPosition(EarbudsPositionFlags)
    /// Wearing (ear) detection; zero means enabled, as in the run-info flag.
    case wearingDetection(Bool)
    case unknown(code: UInt8, data: [UInt8])

    private static let curveFirstLevel = 12
    private static let curveStride = 3

    public static func parse(_ payload: [UInt8], isNotification: Bool) -> [ConfigUpdate] {
        var updates: [ConfigUpdate] = []
        for (_, entry) in parseTLV(payload) {
            // `entry` is `code | data...` (the TLV index byte is the constant 0x00).
            guard let code = entry.first else { continue }
            let data = Array(entry.dropFirst())
            switch ConfigCode(rawValue: code) {
            case .gestures:
                var assignments: [GestureAssignment] = []
                var i = 0
                while i + 2 < data.count {
                    if let tap = TapType(rawValue: data[i]) {
                        assignments.append(GestureAssignment(tap: tap, left: data[i + 1], right: data[i + 2]))
                    }
                    i += 3
                }
                updates.append(.gestures(assignments))
            case .longGestures where data.count >= 2:
                updates.append(.ambientSoundCycle(left: AmbientSoundCycle(rawValue: data[0]),
                                                  right: AmbientSoundCycle(rawValue: data[1])))
            case .autoAnswer where data.count >= 1:
                updates.append(.autoAnswer(data[0] == 0x01))
            case .doubleConnection where data.count >= 1:
                updates.append(.doubleConnection(data[0] == 0x01))
            case .adaptiveNoiseCancelling where data.count >= 1:
                updates.append(.adaptiveNoiseCancelling(data[0] == 0x01))
            case .adaptiveSound where data.count >= 1:
                updates.append(.adaptiveSound(data[0] == 0x01))
            case .equalizerPreset where data.count >= 1:
                updates.append(.equalizerPreset(EqualizerPreset(rawValue: data[0])))
            case .effectStrength where data.count >= 2:
                if isNotification {
                    updates.append(.noiseModeChanged(mode: AmbientSoundMode(rawValue: data[0]), strength: data[1]))
                } else if data[0] == 0x01 {
                    updates.append(.noiseCancellingStrength(NoiseCancellingStrength(rawValue: data[1])))
                } else if data[0] == 0x02 {
                    updates.append(.transparencyStrength(TransparencyStrength(rawValue: data[1])))
                } else {
                    updates.append(.unknown(code: code, data: data))
                }
            case .earbudsPosition where data.count >= 1:
                updates.append(.earbudsPosition(EarbudsPositionFlags(rawValue: data[0])))
            case .earDetection where data.count >= 1:
                updates.append(.wearingDetection(data[0] == 0x00))
            case .equalizerCurve:
                // `entry` index = curveFirstLevel counts from the config code (GB indexes the whole TLV).
                var levels: [UInt8] = []
                var index = curveFirstLevel - 2 // offset into `entry` after len and 00 bytes
                while index < entry.count {
                    levels.append(entry[index])
                    index += curveStride
                }
                updates.append(.equalizerCurve(levels: levels))
            default:
                updates.append(.unknown(code: code, data: data))
            }
        }
        return updates
    }
}
