import XCTest
@testable import BudsProtocol

final class CommandTests: XCTestCase {
    func testNoiseModeCommandsMatchCapture() {
        var builder = CommandBuilder(sequence: 0x0a)
        XCTAssertEqual(builder.encode(.setNoiseMode(.off)), hex(Fixture.ancOff))
        builder = CommandBuilder(sequence: 0x0b)
        XCTAssertEqual(builder.encode(.setNoiseMode(.noiseCancelling)), hex(Fixture.ancOn))
        builder = CommandBuilder(sequence: 0x0d)
        XCTAssertEqual(builder.encode(.setNoiseMode(.transparency)), hex(Fixture.ancTransparency))
    }

    func testSetGestureMatchesCapture() {
        var builder = CommandBuilder(sequence: 0x11)
        let frame = builder.encode(.setGesture(tap: .single, position: .left, action: 0x02))
        XCTAssertEqual(frame, hex(Fixture.setConfigRequest))
    }

    func testSetGestureRightSide() {
        var builder = CommandBuilder(sequence: 0)
        XCTAssertEqual(builder.encode(.setGesture(tap: .double, position: .right, action: 0x03)),
                       hex("fedcbac4f2000700" + "050002" + "01ff03" + "ef"))
    }

    func testDeviceInfoAndRunInfoRequests() {
        var builder = CommandBuilder(sequence: 0x02)
        XCTAssertEqual(builder.encode(.requestDeviceInfo), hex(Fixture.deviceInfoRequest))
        XCTAssertEqual(builder.encode(.requestRunInfo), hex("fedcbac409000503ffffffffef"))
    }

    func testGetConfigRequestsOneFramePerCode() {
        var builder = CommandBuilder(sequence: 0x10)
        XCTAssertEqual(builder.encode(.requestConfig([.gestures, .longGestures])),
                       hex("fedcbac4f30003100002ef") + hex("fedcbac4f3000311000aef"))
    }

    func testEqualizerPresetAndBooleanSettings() {
        var builder = CommandBuilder(sequence: 5)
        XCTAssertEqual(builder.encode(.setEqualizerPreset(.bass)), hex("fedcbac4f2000505" + "03000705" + "ef"))
        XCTAssertEqual(builder.encode(.setBoolean(.doubleConnection, true)), hex("fedcbac4f2000506" + "03000401" + "ef"))
        XCTAssertEqual(builder.encode(.setBoolean(.adaptiveSound, false)), hex("fedcbac4f2000507" + "03002900" + "ef"))
    }

    func testStrengthCommands() {
        var builder = CommandBuilder(sequence: 1)
        XCTAssertEqual(builder.encode(.setNoiseCancellingStrength(.deep)), hex("fedcbac4f2000601" + "04000b0102" + "ef"))
        XCTAssertEqual(builder.encode(.setTransparencyStrength(.voice)), hex("fedcbac4f2000602" + "04000b0201" + "ef"))
    }

    func testAmbientSoundCycleCommand() {
        var builder = CommandBuilder(sequence: 1)
        XCTAssertEqual(builder.encode(.setAmbientSoundCycle(position: .left, cycle: .noiseCancellingTransparency)),
                       hex("fedcbac4f2000601" + "04000a06ff" + "ef"))
        XCTAssertEqual(builder.encode(.setAmbientSoundCycle(position: .right, cycle: .all)),
                       hex("fedcbac4f2000602" + "04000aff07" + "ef"))
    }

    func testWearingDetectionUsesInvertedFlag() {
        var builder = CommandBuilder(sequence: 1)
        XCTAssertEqual(builder.encode(.setWearingDetection(true)), hex("fedcbac408000401" + "020600" + "ef"))
        XCTAssertEqual(builder.encode(.setWearingDetection(false)), hex("fedcbac408000402" + "020601" + "ef"))
    }

    func testSequenceNumberWrapsAround() {
        var builder = CommandBuilder(sequence: 0xff)
        _ = builder.encode(.requestDeviceInfo)
        XCTAssertEqual(builder.sequence, 0x00)
    }
}
