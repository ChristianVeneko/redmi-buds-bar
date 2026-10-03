import BudsProtocol
import Foundation

/// Localized display names for protocol enums.
extension AmbientSoundMode {
    var title: String {
        switch self {
        case .off: tr("Off")
        case .noiseCancelling: tr("Noise cancelling")
        case .transparency: tr("Transparency")
        }
    }

    var symbol: String {
        switch self {
        case .off: "minus.circle"
        case .noiseCancelling: "headphones"
        case .transparency: "ear"
        }
    }
}

extension NoiseCancellingStrength {
    var title: String {
        switch self {
        case .balanced: tr("Balanced")
        case .light: tr("Light")
        case .deep: tr("Deep")
        case .adaptive: tr("Adaptive")
        }
    }
}

extension TransparencyStrength {
    var title: String {
        switch self {
        case .regular: tr("Regular")
        case .voice: tr("Voice enhance")
        case .ambient: tr("Ambient")
        }
    }
}

extension EqualizerPreset {
    var title: String {
        switch self {
        case .standard: tr("Standard")
        case .balanced: tr("Balanced")
        case .treble: tr("Treble boost")
        case .bass: tr("Bass boost")
        case .voice: tr("Voice")
        case .volume: tr("Volume boost")
        case .custom: tr("Custom")
        }
    }
}

extension CustomEqualizerPreset {
    var title: String {
        switch self {
        case .bassBoost: tr("Bass Boost+")
        case .asmr: tr("ASMR")
        case .vocalClarity: tr("Vocal clarity")
        case .night: tr("Night")
        }
    }
}

extension TapType {
    var title: String {
        switch self {
        case .single: tr("Single tap")
        case .double: tr("Double tap")
        case .triple: tr("Triple tap")
        case .long: tr("Long press")
        }
    }

    /// Display order in the gestures section.
    static let displayOrder: [TapType] = [.single, .double, .triple, .long]

    /// Display title for a raw action code of this gesture, or nil if the code is unknown.
    func actionTitle(code: UInt8) -> String? {
        switch self {
        case .long: LongGestureAction(rawValue: code)?.title
        default: GestureAction(rawValue: code)?.title
        }
    }
}

extension GestureAction {
    var title: String {
        switch self {
        case .none: tr("None")
        case .playPause: tr("Play / Pause")
        case .previousTrack: tr("Previous track")
        case .nextTrack: tr("Next track")
        case .volumeUp: tr("Volume up")
        case .volumeDown: tr("Volume down")
        }
    }
}

extension LongGestureAction {
    var title: String {
        switch self {
        case .none: tr("None")
        case .voiceAssistant: tr("Voice assistant")
        case .ambientSoundControl: tr("Noise control")
        }
    }
}

extension AmbientSoundCycle {
    var title: String {
        switch self {
        case .noiseCancellingOff: tr("Noise cancelling / Off")
        case .transparencyOff: tr("Transparency / Off")
        case .noiseCancellingTransparency: tr("Noise cancelling / Transparency")
        case .all: tr("All modes")
        }
    }
}

extension Localizer.Choice {
    var title: String {
        switch self {
        case .system: tr("System")
        case .english: "English"
        case .spanish: "Espa\u{00F1}ol"
        }
    }
}
