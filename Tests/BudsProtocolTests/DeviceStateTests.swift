import XCTest
@testable import BudsProtocol

final class DeviceStateTests: XCTestCase {
    func testAppliesDeviceInfoAndStatus() {
        var state = DeviceState()
        var session = BudsSession()
        for frame in [Fixture.deviceInfoResponse, Fixture.statusNotify2, Fixture.ancNotify] {
            for event in session.receive(hex(frame)).events { state.apply(event) }
        }
        XCTAssertEqual(state.name, "REDMI Buds 8")
        XCTAssertEqual(state.battery.left, BatteryLevel(percent: 95, isCharging: false))
        XCTAssertEqual(state.battery.right, BatteryLevel(percent: 94, isCharging: false))
        // 0xFF in the case byte means "not reported" (case closed or out of range); it replaces the old value.
        XCTAssertNil(state.battery.case)
        XCTAssertEqual(state.noiseMode, .off)
    }

    func testConfigUpdatesPopulateSettings() {
        var state = DeviceState()
        state.apply(.config([
            .equalizerPreset(.voice), .autoAnswer(true), .doubleConnection(false),
            .adaptiveNoiseCancelling(true), .adaptiveSound(false),
            .noiseCancellingStrength(.light), .transparencyStrength(.ambient),
        ]))
        XCTAssertEqual(state.equalizerPreset, .voice)
        XCTAssertEqual(state.autoAnswer, true)
        XCTAssertEqual(state.doubleConnection, false)
        XCTAssertEqual(state.adaptiveNoiseCancelling, true)
        XCTAssertEqual(state.adaptiveSound, false)
        XCTAssertEqual(state.noiseCancellingStrength, .light)
        XCTAssertEqual(state.transparencyStrength, .ambient)
    }

    func testNoiseModeNotificationUpdatesModeAndStrength() {
        var state = DeviceState()
        state.apply(.config([.noiseModeChanged(mode: .noiseCancelling, strength: 2)]))
        XCTAssertEqual(state.noiseMode, .noiseCancelling)
        XCTAssertEqual(state.noiseCancellingStrength, .deep)
        state.apply(.config([.noiseModeChanged(mode: .transparency, strength: 1)]))
        XCTAssertEqual(state.noiseMode, .transparency)
        XCTAssertEqual(state.transparencyStrength, .voice)
    }

    func testRunInfoPopulatesWearingDetection() {
        var state = DeviceState()
        state.apply(.runInfo(RunInfo(noiseMode: .transparency, wearingDetectionEnabled: true)))
        XCTAssertEqual(state.noiseMode, .transparency)
        XCTAssertEqual(state.wearingDetection, true)
    }
}

final class DeviceStatePhase2Tests: XCTestCase {
    func testCaseBatteryIsReplacedByLaterReports() {
        var state = DeviceState()
        state.apply(.status([.battery(BatteryStatus(left: .init(percent: 90, isCharging: false),
                                                    right: .init(percent: 91, isCharging: false),
                                                    case: .init(percent: 50, isCharging: true)))]))
        XCTAssertEqual(state.battery.case, BatteryLevel(percent: 50, isCharging: true))
        state.apply(.status([.battery(BatteryStatus(left: .init(percent: 90, isCharging: false), right: nil, case: nil))]))
        XCTAssertNil(state.battery.case)
        XCTAssertNil(state.battery.right)
    }

    func testEqualizerCurveConfigPopulatesState() {
        var state = DeviceState()
        let codes = EqualizerCurve.bassBoostGains.map { EqualizerCurve.levelCode(for: $0) }
        state.apply(.config([.equalizerCurve(levels: codes)]))
        XCTAssertEqual(state.equalizerCurve?.gains, EqualizerCurve.bassBoostGains)
    }

    func testShortEqualizerCurveIsIgnored() {
        var state = DeviceState()
        state.apply(.config([.equalizerCurve(levels: [0, 1, 2])]))
        XCTAssertNil(state.equalizerCurve)
    }

    func testPositionAndWearingDetectionConfig() {
        var state = DeviceState()
        state.apply(.config([.earbudsPosition(EarbudsPositionFlags(rawValue: 0x0c)), .wearingDetection(true)]))
        XCTAssertEqual(state.position?.rawValue, 0x0c)
        XCTAssertEqual(state.wearingDetection, true)
    }
}
