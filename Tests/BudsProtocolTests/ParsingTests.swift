import XCTest
@testable import BudsProtocol

final class ParsingTests: XCTestCase {
    private func payload(_ frame: String) -> [UInt8] {
        var decoder = FrameDecoder()
        return decoder.feed(hex(frame)).first!.payload
    }

    func testBatteryLevelDecoding() {
        XCTAssertEqual(BatteryLevel(raw: 0xde), BatteryLevel(percent: 94, isCharging: true))
        XCTAssertEqual(BatteryLevel(raw: 0x4f), BatteryLevel(percent: 79, isCharging: false))
        XCTAssertNil(BatteryLevel(raw: 0xff))
    }

    func testDeviceInfo() {
        let info = DeviceInfo.parse(payload(Fixture.deviceInfoResponse))
        XCTAssertEqual(info.name, "REDMI Buds 8")
        XCTAssertEqual(info.firmware, "5.2.0.2")
        XCTAssertEqual(info.secondaryFirmware, "5.2.0.2")
        XCTAssertEqual(info.hardware, "VID: 0x2717, PID: 0x50F3")
        XCTAssertEqual(info.battery.left, BatteryLevel(percent: 94, isCharging: true))
        XCTAssertEqual(info.battery.right, BatteryLevel(percent: 94, isCharging: true))
        XCTAssertEqual(info.battery.case, BatteryLevel(percent: 79, isCharging: false))
    }

    func testDeviceInfoToleratesTruncatedPayload() {
        let truncated = Array(payload(Fixture.deviceInfoResponse).prefix(20))
        _ = DeviceInfo.parse(truncated)
        _ = DeviceInfo.parse([])
        _ = DeviceInfo.parse([0x05])
    }

    func testStatusBatteryNotifications() {
        XCTAssertEqual(
            StatusUpdate.parse(payload(Fixture.statusNotify1)),
            [.battery(BatteryStatus(left: .init(percent: 94, isCharging: true),
                                    right: .init(percent: 94, isCharging: true),
                                    case: .init(percent: 79, isCharging: false)))]
        )
        XCTAssertEqual(
            StatusUpdate.parse(payload(Fixture.statusNotify2)),
            [.battery(BatteryStatus(left: .init(percent: 95, isCharging: false),
                                    right: .init(percent: 94, isCharging: false),
                                    case: nil))]
        )
        XCTAssertEqual(
            StatusUpdate.parse(payload(Fixture.statusNotify3)),
            [.battery(BatteryStatus(left: .init(percent: 94, isCharging: false),
                                    right: .init(percent: 93, isCharging: false),
                                    case: nil))]
        )
    }

    func testStatusNoiseModeNotification() {
        XCTAssertEqual(StatusUpdate.parse(payload(Fixture.ancNotify)), [.noiseMode(.off)])
        XCTAssertEqual(StatusUpdate.parse(hex("020401")), [.noiseMode(.noiseCancelling)])
        XCTAssertEqual(StatusUpdate.parse(hex("020402")), [.noiseMode(.transparency)])
    }

    func testStatusUnknownEntryIsKept() {
        XCTAssertEqual(StatusUpdate.parse(hex("03 7a 01 02")), [.unknown(index: 0x7a, data: [1, 2])])
    }

    func testRunInfo() {
        let info = RunInfo.parse(hex("02 09 01 02 0a 00"))
        XCTAssertEqual(info.noiseMode, .noiseCancelling)
        XCTAssertEqual(info.wearingDetectionEnabled, true)
        XCTAssertEqual(RunInfo.parse(hex("02 0a 01")).wearingDetectionEnabled, false)
    }

    func testConfigNotificationCarriesNoiseMode() {
        XCTAssertEqual(
            ConfigUpdate.parse(payload(Fixture.configNotify), isNotification: true),
            [.noiseModeChanged(mode: .off, strength: 0)]
        )
        XCTAssertEqual(
            ConfigUpdate.parse(hex("04 00 0b 01 02"), isNotification: true),
            [.noiseModeChanged(mode: .noiseCancelling, strength: 2)]
        )
    }

    func testConfigGetResponseGesturesAndLongPressCycle() {
        let updates = ConfigUpdate.parse(payload(Fixture.getConfigResponse), isNotification: false)
        XCTAssertEqual(updates.count, 2)
        guard case .gestures(let gestures) = updates[0] else { return XCTFail("expected gestures") }
        XCTAssertEqual(gestures, [
            GestureAssignment(tap: .double, left: 0x01, right: 0x01),
            GestureAssignment(tap: .triple, left: 0x03, right: 0x03),
            GestureAssignment(tap: .long, left: 0x06, right: 0x06),
            GestureAssignment(tap: .single, left: 0x08, right: 0x08),
        ])
        XCTAssertEqual(updates[1], .ambientSoundCycle(left: .noiseCancellingTransparency, right: .noiseCancellingTransparency))
    }

    func testConfigSimpleValues() {
        XCTAssertEqual(ConfigUpdate.parse(hex("03 00 03 01"), isNotification: false), [.autoAnswer(true)])
        XCTAssertEqual(ConfigUpdate.parse(hex("03 00 04 00"), isNotification: false), [.doubleConnection(false)])
        XCTAssertEqual(ConfigUpdate.parse(hex("03 00 25 01"), isNotification: false), [.adaptiveNoiseCancelling(true)])
        XCTAssertEqual(ConfigUpdate.parse(hex("03 00 29 01"), isNotification: false), [.adaptiveSound(true)])
        XCTAssertEqual(ConfigUpdate.parse(hex("03 00 07 05"), isNotification: false), [.equalizerPreset(.bass)])
    }

    func testConfigEffectStrengthResponse() {
        XCTAssertEqual(ConfigUpdate.parse(hex("04 00 0b 01 02"), isNotification: false),
                       [.noiseCancellingStrength(.deep)])
        XCTAssertEqual(ConfigUpdate.parse(hex("04 00 0b 02 01"), isNotification: false),
                       [.transparencyStrength(.voice)])
    }

    func testConfigUnknownCodeIsKept() {
        XCTAssertEqual(ConfigUpdate.parse(hex("03 00 7e 09"), isNotification: false),
                       [.unknown(code: 0x7e, data: [0x09])])
    }

    func testConfigMultipleEntriesAndTruncation() {
        let updates = ConfigUpdate.parse(hex("03 00 03 01 03 00 04 01"), isNotification: false)
        XCTAssertEqual(updates, [.autoAnswer(true), .doubleConnection(true)])
        _ = ConfigUpdate.parse(hex("09 00 02 01"), isNotification: false)
        _ = ConfigUpdate.parse([], isNotification: false)
    }
}
