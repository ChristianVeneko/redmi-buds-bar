import XCTest
@testable import BudsProtocol

final class BudsModelResolutionTests: XCTestCase {
    func testResolvesUserDevice() {
        XCTAssertEqual(BudsModel.resolve(name: "REDMI Buds 8").id, .buds8)
    }

    func testActiveAndNonActiveDoNotCrossResolve() {
        XCTAssertEqual(BudsModel.resolve(name: "REDMI Buds 8 Active").id, .buds8Active)
        XCTAssertEqual(BudsModel.resolve(name: "REDMI Buds 8").id, .buds8)
        XCTAssertEqual(BudsModel.resolve(name: "Redmi Buds 6 Active").id, .buds6Active)
        XCTAssertEqual(BudsModel.resolve(name: "Redmi Buds 6").id, .buds6)
    }

    func testResolutionIsCaseInsensitive() {
        XCTAssertEqual(BudsModel.resolve(name: "redmi buds 8 active").id, .buds8Active)
        XCTAssertEqual(BudsModel.resolve(name: "REDMI BUDS 8").id, .buds8)
        XCTAssertEqual(BudsModel.resolve(name: "Redmi Buds 5 PRO").id, .buds5Pro)
    }

    func testResolutionIgnoresSurroundingAndRepeatedWhitespace() {
        XCTAssertEqual(BudsModel.resolve(name: "  Redmi  Buds 3 Pro ").id, .buds3Pro)
    }

    func testAllKnownNames() {
        let expected: [(String, BudsModel.Identifier)] = [
            ("Redmi Buds 3 Pro", .buds3Pro), ("Redmi Buds 4 Active", .buds4Active),
            ("Redmi Buds 5 Pro", .buds5Pro), ("Redmi Buds 6", .buds6), ("Redmi Buds 6 Pro", .buds6Pro),
            ("Redmi Buds 6 Active", .buds6Active), ("Redmi Buds 6 Lite", .buds6Lite),
            ("REDMI Buds 8", .buds8), ("REDMI Buds 8 Active", .buds8Active),
        ]
        for (name, id) in expected { XCTAssertEqual(BudsModel.resolve(name: name).id, id, name) }
    }

    /// Gadgetbridge matches ".*Redmi Buds 6 Lite.*".
    func testLiteMatchesAnywhereInName() {
        XCTAssertEqual(BudsModel.resolve(name: "Alice's Redmi Buds 6 Lite").id, .buds6Lite)
        XCTAssertEqual(BudsModel.resolve(name: "redmi buds 6 lite (L)").id, .buds6Lite)
    }

    func testUnknownRedmiBudsFallBackToGeneric() {
        XCTAssertEqual(BudsModel.resolve(name: "Redmi Buds 7").id, .generic)
        XCTAssertEqual(BudsModel.resolve(name: "REDMI Buds 8 Pro").id, .generic)
        XCTAssertEqual(BudsModel.resolve(name: "Redmi Buds 60").id, .generic)
        XCTAssertEqual(BudsModel.resolve(name: "").id, .generic)
    }

    func testIsRedmiBuds() {
        XCTAssertTrue(BudsModel.isRedmiBuds(name: "REDMI Buds 8"))
        XCTAssertTrue(BudsModel.isRedmiBuds(name: "redmi buds 7 pro"))
        XCTAssertTrue(BudsModel.isRedmiBuds(name: "Redmi Buds"))
        XCTAssertFalse(BudsModel.isRedmiBuds(name: "AirPods Pro"))
        XCTAssertFalse(BudsModel.isRedmiBuds(name: "Redmi Watch 4"))
        XCTAssertFalse(BudsModel.isRedmiBuds(name: "RedmiBuds"))
        XCTAssertFalse(BudsModel.isRedmiBuds(name: nil))
    }

    func testEveryIdentifierHasOneModel() {
        XCTAssertEqual(Set(BudsModel.all.map(\.id)), Set(BudsModel.Identifier.allCases).subtracting([.generic]))
        XCTAssertEqual(BudsModel.all.count, BudsModel.Identifier.allCases.count - 1)
    }
}

final class BudsModelCapabilityTests: XCTestCase {
    func testBuds8IsBuds8ActiveWithNoiseControl() {
        let active = BudsModel.resolve(name: "REDMI Buds 8 Active")
        let plain = BudsModel.resolve(name: "REDMI Buds 8")
        XCTAssertTrue(active.ambientSoundModes.isEmpty)
        XCTAssertEqual(plain.ambientSoundModes, AmbientSoundMode.allCases)
        XCTAssertEqual(plain.equalizerPresets, active.equalizerPresets)
        XCTAssertEqual(plain.supportsCustomEqualizer, active.supportsCustomEqualizer)
        XCTAssertEqual(plain.supportsAdaptiveSound, active.supportsAdaptiveSound)
        XCTAssertEqual(plain.supportsFindDevice, active.supportsFindDevice)
        XCTAssertEqual(plain.supportsDoubleConnection, active.supportsDoubleConnection)
        XCTAssertEqual(plain.singleTapActions, active.singleTapActions)
        XCTAssertEqual(plain.longPressActions, active.longPressActions)
    }

    func testBuds8ActiveCapabilities() {
        let model = BudsModel.resolve(name: "REDMI Buds 8 Active")
        XCTAssertEqual(model.equalizerPresets, [.balanced, .treble, .bass, .voice, .volume, .custom])
        XCTAssertTrue(model.supportsCustomEqualizer)
        XCTAssertTrue(model.supportsAdaptiveSound)
        XCTAssertTrue(model.supportsFindDevice)
        XCTAssertTrue(model.supportsFindPerEarbud)
        XCTAssertTrue(model.supportsDoubleConnection)
        XCTAssertFalse(model.supportsWearingDetection)
        XCTAssertFalse(model.supportsAutoAnswer)
        XCTAssertEqual(model.longPressActions, [.none, .voiceAssistant])
        XCTAssertTrue(model.ambientSoundCycles.isEmpty)
    }

    func testBuds5Pro6And6ProShareCapabilities() {
        let pro5 = BudsModel.resolve(name: "Redmi Buds 5 Pro")
        for name in ["Redmi Buds 6", "Redmi Buds 6 Pro"] {
            let other = BudsModel.resolve(name: name)
            XCTAssertEqual(other.ambientSoundModes, pro5.ambientSoundModes, name)
            XCTAssertEqual(other.noiseCancellingStrengths, pro5.noiseCancellingStrengths, name)
            XCTAssertEqual(other.transparencyStrengths, pro5.transparencyStrengths, name)
            XCTAssertEqual(other.equalizerPresets, pro5.equalizerPresets, name)
            XCTAssertEqual(other.supportsCustomEqualizer, pro5.supportsCustomEqualizer, name)
            XCTAssertEqual(other.supportsAdaptiveNoiseCancelling, pro5.supportsAdaptiveNoiseCancelling, name)
            XCTAssertEqual(other.longPressActions, pro5.longPressActions, name)
        }
        XCTAssertEqual(pro5.noiseCancellingStrengths, [.balanced, .light, .deep])
        XCTAssertEqual(pro5.transparencyStrengths, TransparencyStrength.allCases)
        XCTAssertEqual(pro5.equalizerPresets, [.standard, .treble, .bass, .voice, .custom])
        XCTAssertTrue(pro5.supportsAdaptiveNoiseCancelling)
        XCTAssertFalse(pro5.supportsFindDevice)
    }

    func testBuds3Pro() {
        let model = BudsModel.resolve(name: "Redmi Buds 3 Pro")
        XCTAssertEqual(model.noiseCancellingStrengths, NoiseCancellingStrength.allCases)
        XCTAssertEqual(model.transparencyStrengths, [.regular, .voice])
        XCTAssertEqual(model.equalizerPresets, [.standard, .treble, .bass, .voice])
        XCTAssertFalse(model.supportsCustomEqualizer)
        XCTAssertTrue(model.singleTapActions.isEmpty)
        XCTAssertTrue(model.supportsWearingDetection && model.supportsAutoAnswer && model.supportsDoubleConnection)
    }

    func testBuds4ActiveOffersNothingBeyondBattery() {
        let model = BudsModel.resolve(name: "Redmi Buds 4 Active")
        XCTAssertTrue(model.ambientSoundModes.isEmpty)
        XCTAssertFalse(model.hasEqualizer)
        XCTAssertFalse(model.hasGestures)
        XCTAssertFalse(model.supportsFindDevice)
    }

    func testBuds6ActiveHasVolumePresetAndFind() {
        let model = BudsModel.resolve(name: "Redmi Buds 6 Active")
        XCTAssertEqual(model.equalizerPresets, [.standard, .treble, .bass, .voice, .volume])
        XCTAssertTrue(model.supportsFindDevice && model.supportsFindPerEarbud)
        XCTAssertTrue(model.ambientSoundModes.isEmpty)
        XCTAssertFalse(model.supportsCustomEqualizer)
    }

    func testBuds6LiteUsesCustomEqualizerOnly() {
        let model = BudsModel.resolve(name: "Redmi Buds 6 Lite")
        XCTAssertTrue(model.equalizerPresets.isEmpty)
        XCTAssertTrue(model.supportsCustomEqualizer)
        XCTAssertTrue(model.hasEqualizer)
        XCTAssertEqual(model.ambientSoundModes, AmbientSoundMode.allCases)
        XCTAssertTrue(model.supportsFindDevice)
        XCTAssertTrue(model.supportsAutoAnswer)
        XCTAssertEqual(model.gestureActions(for: .double), GestureAction.allCases.map(\.rawValue))
    }

    func testGestureActionLists() {
        let model = BudsModel.resolve(name: "REDMI Buds 8")
        XCTAssertEqual(model.gestureActions(for: .single), GestureAction.allCases.map(\.rawValue))
        XCTAssertFalse(model.gestureActions(for: .double).contains(GestureAction.none.rawValue))
        XCTAssertEqual(model.gestureActions(for: .triple), model.gestureActions(for: .double))
        XCTAssertEqual(model.gestureActions(for: .long), [LongGestureAction.none, .voiceAssistant].map(\.rawValue))
        XCTAssertTrue(model.hasGestures)
        XCTAssertTrue(model.supports(tap: .single))
        XCTAssertTrue(BudsModel.resolve(name: "Redmi Buds 3 Pro").gestureActions(for: .single).isEmpty)
        XCTAssertFalse(BudsModel.resolve(name: "Redmi Buds 3 Pro").supports(tap: .single))
    }

    func testGenericFallbackIsMinimal() {
        let model = BudsModel.genericFallback
        XCTAssertEqual(model.id, .generic)
        XCTAssertEqual(model.ambientSoundModes, AmbientSoundMode.allCases) // the only command confirmed on hardware
        XCTAssertTrue(model.equalizerPresets.isEmpty)
        XCTAssertFalse(model.supportsCustomEqualizer)
        XCTAssertFalse(model.hasEqualizer)
        XCTAssertFalse(model.hasGestures)
        XCTAssertFalse(model.supportsFindDevice)
        XCTAssertFalse(model.supportsWearingDetection || model.supportsAutoAnswer || model.supportsDoubleConnection)
        XCTAssertFalse(model.supportsAdaptiveSound || model.supportsAdaptiveNoiseCancelling)
    }

    func testOnlyBuds8IsMarkedHardwareTested() {
        for model in BudsModel.all {
            XCTAssertEqual(model.isTestedOnHardware, model.id == .buds8, "\(model.id)")
        }
    }

    func testUniqueDisplayNames() {
        let names = BudsModel.all.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
    }
}

final class DeviceSelectionTests: XCTestCase {
    private func candidates() -> [DeviceCandidate] {
        [DeviceCandidate(id: "A", name: "Redmi Buds 6", isConnected: false),
         DeviceCandidate(id: "B", name: "REDMI Buds 8", isConnected: true),
         DeviceCandidate(id: "C", name: "AirPods", isConnected: true),
         DeviceCandidate(id: "D", name: "Redmi Buds 5 Pro", isConnected: true)]
    }

    func testOnlyRedmiBudsAreEligible() {
        XCTAssertEqual(DeviceSelection.eligible(candidates()).map(\.id), ["A", "B", "D"])
    }

    func testPrefersConnectedDevice() {
        XCTAssertEqual(DeviceSelection.choose(from: candidates(), preferredID: nil)?.id, "B")
    }

    func testExplicitPreferenceWinsWhenPresent() {
        XCTAssertEqual(DeviceSelection.choose(from: candidates(), preferredID: "A")?.id, "A")
    }

    func testUnknownPreferenceIsIgnored() {
        XCTAssertEqual(DeviceSelection.choose(from: candidates(), preferredID: "zzz")?.id, "B")
    }

    func testFallsBackToFirstWhenNoneConnected() {
        let none = candidates().map { DeviceCandidate(id: $0.id, name: $0.name, isConnected: false) }
        XCTAssertEqual(DeviceSelection.choose(from: none, preferredID: nil)?.id, "A")
    }

    func testNoEligibleDevice() {
        XCTAssertNil(DeviceSelection.choose(from: [DeviceCandidate(id: "C", name: "AirPods", isConnected: true)], preferredID: nil))
        XCTAssertNil(DeviceSelection.choose(from: [], preferredID: nil))
    }
}
