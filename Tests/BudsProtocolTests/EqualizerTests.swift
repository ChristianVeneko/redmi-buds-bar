import XCTest
@testable import BudsProtocol

final class EqualizerTests: XCTestCase {
    func testBandFrequenciesMatchGadgetbridge() {
        XCTAssertEqual(EqualizerCurve.bandFrequencies, [62, 125, 250, 500, 1000, 2016, 4000, 8000, 12000, 16000])
    }

    func testLevelCodes() {
        XCTAssertEqual(EqualizerCurve.levelCode(for: 0), 0x00)
        XCTAssertEqual(EqualizerCurve.levelCode(for: 1), 0x01)
        XCTAssertEqual(EqualizerCurve.levelCode(for: 6), 0x06)
        XCTAssertEqual(EqualizerCurve.levelCode(for: -1), 0x81)
        XCTAssertEqual(EqualizerCurve.levelCode(for: -6), 0x86)
    }

    func testLevelCodesAreClampedToProtocolRange() {
        XCTAssertEqual(EqualizerCurve.levelCode(for: 9), 0x06)
        XCTAssertEqual(EqualizerCurve.levelCode(for: -9), 0x86)
    }

    func testGainDecoding() {
        XCTAssertEqual(EqualizerCurve.gain(forCode: 0x83), -3)
        XCTAssertEqual(EqualizerCurve.gain(forCode: 0x04), 4)
        XCTAssertEqual(EqualizerCurve.gain(forCode: 0x00), 0)
        XCTAssertNil(EqualizerCurve.gain(forCode: 0x40))
        XCTAssertNil(EqualizerCurve.gain(forCode: 0x87))
    }

    func testCurveInitRequiresTenBands() {
        XCTAssertNil(EqualizerCurve(gains: [0, 1]))
        XCTAssertNotNil(EqualizerCurve(gains: [Int](repeating: 0, count: 10)))
    }

    func testCurveInitClampsGains() {
        XCTAssertEqual(EqualizerCurve(gains: [9, -9, 0, 0, 0, 0, 0, 0, 0, 0])?.gains,
                       [6, -6, 0, 0, 0, 0, 0, 0, 0, 0])
    }

    /// Port of Gadgetbridge `encodeSetCustomEqualizer`: `24 00 37 05 01 01 0A` then (freq BE16, level) per band.
    func testCustomEqualizerPayloadLayout() {
        let curve = EqualizerCurve(gains: [-6, -3, 0, 1, 6, 0, 0, 0, 0, -1])!
        let expectedPayload = hex(
            "24 00 37 05 01 01 0a"
            + "003e 86" + "007d 83" + "00fa 00" + "01f4 01" + "03e8 06"
            + "07e0 00" + "0fa0 00" + "1f40 00" + "2ee0 00" + "3e80 81"
        )
        XCTAssertEqual(curve.encodePayload(), expectedPayload)
    }

    func testCustomEqualizerFrame() {
        var builder = CommandBuilder(sequence: 0x20)
        let flat = EqualizerCurve(gains: [Int](repeating: 0, count: 10))!
        let expected = hex(
            "fedcbac4f2 0026 20"
            + "24 00 37 05 01 01 0a"
            + "003e00 007d00 00fa00 01f400 03e800 07e000 0fa000 1f4000 2ee000 3e8000"
            + "ef"
        )
        XCTAssertEqual(builder.encode(.setCustomEqualizer(flat)), expected)
    }

    func testCurveParsedFromConfigAtGadgetbridgeOffsets() {
        // GET_CONFIG response entry: levels start at payload offset 12 with a stride of 3.
        var entry: [UInt8] = [0x24, 0x00, 0x37, 0x05, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0a]
        for (i, gain) in EqualizerCurve.bassBoostGains.enumerated() {
            let f = EqualizerCurve.bandFrequencies[i]
            entry += [UInt8(f >> 8), UInt8(f & 0xFF), EqualizerCurve.levelCode(for: gain)]
        }
        entry[0] = UInt8(entry.count - 1) // length byte counts everything after itself
        let updates = ConfigUpdate.parse(entry, isNotification: false)
        guard case .equalizerCurve(let levels)? = updates.first else { return XCTFail("expected curve") }
        XCTAssertEqual(levels.count, 10)
        XCTAssertEqual(levels.map { EqualizerCurve.gain(forCode: $0) }, EqualizerCurve.bassBoostGains.map { Optional($0) })
    }

    func testAppPresetsAreWithinProtocolRange() {
        for preset in CustomEqualizerPreset.allCases {
            XCTAssertEqual(preset.curve.gains.count, 10, "\(preset)")
            XCTAssertTrue(preset.curve.gains.allSatisfy { (-6...6).contains($0) }, "\(preset)")
        }
    }

    func testAppPresetsAreDistinctAndIdentifiable() {
        let curves = CustomEqualizerPreset.allCases.map(\.curve.gains)
        XCTAssertEqual(Set(curves).count, curves.count)
        for preset in CustomEqualizerPreset.allCases {
            XCTAssertEqual(CustomEqualizerPreset.matching(preset.curve), preset)
        }
        XCTAssertNil(CustomEqualizerPreset.matching(EqualizerCurve(gains: [Int](repeating: 0, count: 10))!))
    }

    func testPresetShapes() {
        let bass = CustomEqualizerPreset.bassBoost.curve.gains
        XCTAssertGreaterThanOrEqual(bass[0], 5)
        XCTAssertLessThanOrEqual(bass[9], 0)

        let asmr = CustomEqualizerPreset.asmr.curve.gains
        XCTAssertLessThan(asmr[0], 0)           // lows slightly reduced
        XCTAssertGreaterThan(asmr[8], 0)        // air boosted
        XCTAssertGreaterThan(asmr[9], 0)

        let night = CustomEqualizerPreset.night.curve.gains
        XCTAssertLessThan(night[9], 0)          // reduced highs
        XCTAssertLessThanOrEqual(night.map(abs).max()!, 4) // gentle

        let vocal = CustomEqualizerPreset.vocalClarity.curve.gains
        XCTAssertGreaterThan(vocal[5], 0)       // presence band
    }

    func testOnlyAsmrSuggestsNoiseCancelling() {
        XCTAssertTrue(CustomEqualizerPreset.asmr.suggestsNoiseCancelling)
        XCTAssertFalse(CustomEqualizerPreset.bassBoost.suggestsNoiseCancelling)
    }
}

final class FindAndConfigTests: XCTestCase {
    func testStopFindFrame() {
        var builder = CommandBuilder(sequence: 1)
        XCTAssertEqual(builder.encode(.stopFindEarbuds), hex("fedcbac4f2000601" + "0400090003" + "ef"))
    }

    func testStartFindSendsStopThenStart() {
        var builder = CommandBuilder(sequence: 1)
        XCTAssertEqual(builder.frames(.startFindEarbuds(.left)),
                       [hex("fedcbac4f2000601" + "0400090003" + "ef"), hex("fedcbac4f2000602" + "0400090101" + "ef")])
        XCTAssertEqual(builder.frames(.startFindEarbuds(.right)).last, hex("fedcbac4f2000604" + "0400090102" + "ef"))
        XCTAssertEqual(builder.frames(.startFindEarbuds(.both)).last, hex("fedcbac4f2000606" + "0400090103" + "ef"))
    }

    func testEarbudsPositionConfig() {
        XCTAssertEqual(ConfigUpdate.parse(hex("03 00 0c 0c"), isNotification: true),
                       [.earbudsPosition(EarbudsPositionFlags(rawValue: 0x0c))])
    }

    func testPositionFlags() {
        let flags = EarbudsPositionFlags(rawValue: 0x0c)
        XCTAssertTrue(flags.leftInCase)
        XCTAssertTrue(flags.rightInCase)
        XCTAssertFalse(flags.leftWorn)
        XCTAssertFalse(flags.rightWorn)
        XCTAssertTrue(EarbudsPositionFlags(rawValue: 0x03).leftWorn)
    }

    /// Observed on a real device: `Unknown config 6: 0000`. Zero means enabled, like the run-info flag.
    func testEarDetectionConfig() {
        XCTAssertEqual(ConfigUpdate.parse(hex("04 00 06 00 00"), isNotification: false), [.wearingDetection(true)])
        XCTAssertEqual(ConfigUpdate.parse(hex("04 00 06 01 01"), isNotification: false), [.wearingDetection(false)])
    }
}

final class LowBatteryMonitorTests: XCTestCase {
    private func status(left: Int?, right: Int?, charging: Bool = false) -> BatteryStatus {
        BatteryStatus(left: left.map { BatteryLevel(percent: $0, isCharging: charging) },
                      right: right.map { BatteryLevel(percent: $0, isCharging: charging) })
    }

    func testAlertsOncePerEarbudBelowThreshold() {
        var monitor = LowBatteryMonitor(threshold: 15)
        XCTAssertEqual(monitor.update(status(left: 40, right: 40)), [])
        XCTAssertEqual(monitor.update(status(left: 14, right: 40)), [.left])
        XCTAssertEqual(monitor.update(status(left: 13, right: 40)), [])
        XCTAssertEqual(monitor.update(status(left: 13, right: 12)), [.right])
    }

    func testChargingEarbudDoesNotAlert() {
        var monitor = LowBatteryMonitor(threshold: 15)
        XCTAssertEqual(monitor.update(status(left: 5, right: 5, charging: true)), [])
    }

    func testRearmsAfterRecovery() {
        var monitor = LowBatteryMonitor(threshold: 15)
        XCTAssertEqual(monitor.update(status(left: 10, right: nil)), [.left])
        XCTAssertEqual(monitor.update(status(left: 18, right: nil)), []) // within hysteresis, still armed off
        XCTAssertEqual(monitor.update(status(left: 10, right: nil)), [])
        XCTAssertEqual(monitor.update(status(left: 25, right: nil)), [])
        XCTAssertEqual(monitor.update(status(left: 9, right: nil)), [.left])
    }

    func testUnknownLevelIsIgnored() {
        var monitor = LowBatteryMonitor(threshold: 15)
        XCTAssertEqual(monitor.update(status(left: nil, right: nil)), [])
    }
}
