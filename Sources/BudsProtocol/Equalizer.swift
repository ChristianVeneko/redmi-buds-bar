/// Ten-band custom equalizer curve. Gains are whole dB steps in `-6...6`, the range of
/// Gadgetbridge's `RedmiBudsEqualizerBandLevel`.
public struct EqualizerCurve: Equatable, Hashable, Sendable {
    /// Band centre frequencies in Hz (note the 2016 Hz band, as in Gadgetbridge's `RedmiBudsEqualizerBand`).
    public static let bandFrequencies: [Int] = [62, 125, 250, 500, 1000, 2016, 4000, 8000, 12000, 16000]
    public static let gainRange: ClosedRange<Int> = -6...6

    public let gains: [Int]

    /// Returns nil unless exactly one gain per band is given. Gains are clamped to the allowed range.
    public init?(gains: [Int]) {
        guard gains.count == Self.bandFrequencies.count else { return nil }
        self.gains = gains.map { min(max($0, Self.gainRange.lowerBound), Self.gainRange.upperBound) }
    }

    /// Wire code of a gain: positive values as-is, negative values as `0x80 | magnitude`.
    public static func levelCode(for gain: Int) -> UInt8 {
        let clamped = min(max(gain, gainRange.lowerBound), gainRange.upperBound)
        return clamped >= 0 ? UInt8(clamped) : 0x80 | UInt8(-clamped)
    }

    /// Inverse of `levelCode(for:)`. Returns nil for codes outside the protocol range.
    public static func gain(forCode code: UInt8) -> Int? {
        let magnitude = Int(code & 0x7F)
        guard magnitude <= 6, code & 0x7F == code || code & 0x80 != 0 else { return nil }
        if code & 0x80 != 0 { return magnitude == 0 ? 0 : -magnitude }
        return magnitude
    }

    /// `SET_CONFIG` payload, ported from Gadgetbridge `encodeSetCustomEqualizer`:
    /// `24 00 37 05 01 01 <bandCount>` followed by `freq(BE16) level` for every band.
    public func encodePayload() -> [UInt8] {
        var payload: [UInt8] = [0x24, 0x00, ConfigCode.equalizerCurve.rawValue, 0x05, 0x01, 0x01, UInt8(gains.count)]
        for (frequency, gain) in zip(Self.bandFrequencies, gains) {
            payload.append(UInt8((frequency >> 8) & 0xFF))
            payload.append(UInt8(frequency & 0xFF))
            payload.append(Self.levelCode(for: gain))
        }
        return payload
    }

    /// Builds a curve from raw level bytes as reported by the earbuds. Nil if a band is missing or invalid.
    init?(levelCodes: [UInt8]) {
        guard levelCodes.count >= Self.bandFrequencies.count else { return nil }
        let gains = levelCodes.prefix(Self.bandFrequencies.count).compactMap { Self.gain(forCode: $0) }
        guard gains.count == Self.bandFrequencies.count else { return nil }
        self.init(gains: gains)
    }

    public static let flat = EqualizerCurve(gains: [Int](repeating: 0, count: 10))!
    public static let bassBoostGains = [6, 6, 5, 3, 1, 0, 0, 0, 0, 0]
}

/// App-defined presets written as a custom curve (the firmware only knows its own preset codes).
/// Bands: 62, 125, 250, 500, 1k, 2k, 4k, 8k, 12k, 16k Hz.
public enum CustomEqualizerPreset: String, CaseIterable, Sendable {
    /// Strong low-end boost, tapering off by 1 kHz.
    case bassBoost
    /// Lows slightly reduced, rising presence and air bands for fine detail.
    case asmr
    /// Cuts the low end and lifts the 500 Hz - 4 kHz speech range.
    case vocalClarity
    /// Gentle curve with a small bass lift and progressively reduced highs for quiet listening.
    case night

    public var curve: EqualizerCurve {
        let gains: [Int]
        switch self {
        case .bassBoost: gains = EqualizerCurve.bassBoostGains
        case .asmr: gains = [-2, -2, -1, 0, 1, 2, 3, 4, 5, 4]
        case .vocalClarity: gains = [-2, -2, -1, 1, 2, 3, 3, 2, 0, 0]
        case .night: gains = [1, 1, 1, 0, 0, -1, -2, -3, -3, -4]
        }
        return EqualizerCurve(gains: gains)!
    }

    /// ASMR is meant for immersive listening, so the UI offers to enable noise cancelling.
    public var suggestsNoiseCancelling: Bool { self == .asmr }

    public static func matching(_ curve: EqualizerCurve) -> CustomEqualizerPreset? {
        allCases.first { $0.curve == curve }
    }
}
