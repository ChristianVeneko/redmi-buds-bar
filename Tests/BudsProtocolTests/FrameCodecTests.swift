import XCTest
@testable import BudsProtocol

final class FrameCodecTests: XCTestCase {
    func testEncodesPhoneRequest() {
        let payload = [0x01] + hex(Fixture.challengeFromPhone)
        let message = Message(type: .phoneRequest, opcode: .authChallenge, sequence: 0x00, payload: payload)
        XCTAssertEqual(message.encode(), hex(Fixture.phoneAuthChallenge))
    }

    func testEncodesResponseWithStatusByte() {
        let payload = [0x01] + hex(Fixture.answerFromPhone)
        let message = Message(type: .response, opcode: .authChallenge, sequence: 0x5d, payload: payload)
        XCTAssertEqual(message.encode(), hex(Fixture.phoneAuthAnswer))
    }

    func testDecodesRequestFrame() {
        var decoder = FrameDecoder()
        let messages = decoder.feed(hex(Fixture.budsAuthChallenge))
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].type, .earbudsRequest)
        XCTAssertEqual(messages[0].opcode, .authChallenge)
        XCTAssertEqual(messages[0].sequence, 0x5d)
        XCTAssertEqual(messages[0].payload, [0x01] + [UInt8](repeating: 0, count: 16))
    }

    func testDecodesResponseFrameSkippingStatusByte() {
        var decoder = FrameDecoder()
        let messages = decoder.feed(hex(Fixture.getConfigResponse))
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].type, .response)
        XCTAssertEqual(messages[0].opcode, .getConfig)
        XCTAssertEqual(messages[0].sequence, 0x10)
        XCTAssertEqual(messages[0].payload.count, 23)
    }

    func testDecodesEmptyPayloadResponse() {
        var decoder = FrameDecoder()
        let messages = decoder.feed(hex(Fixture.setConfigResponse))
        XCTAssertEqual(messages, [Message(type: .response, opcode: .setConfig, sequence: 0x11, payload: [])])
    }

    func testDecodesNotifyType() {
        var decoder = FrameDecoder()
        let messages = decoder.feed(hex(Fixture.statusNotify1))
        XCTAssertEqual(messages.first?.type, .earbudsNotify)
        XCTAssertEqual(messages.first?.opcode, .reportStatus)
        XCTAssertEqual(messages.first?.payload, hex("0400dede4f"))
    }

    func testEveryFixtureRoundTrips() {
        let frames = [
            Fixture.phoneAuthChallenge, Fixture.budsAuthResponse, Fixture.phoneAuthConfirm,
            Fixture.budsAuthConfirmResponse, Fixture.budsAuthChallenge, Fixture.phoneAuthAnswer,
            Fixture.budsAuthConfirm, Fixture.phoneAuthConfirmReply, Fixture.deviceInfoRequest,
            Fixture.deviceInfoResponse, Fixture.statusNotify1, Fixture.statusNotify2,
            Fixture.statusNotify3, Fixture.ancOff, Fixture.ancOn, Fixture.ancTransparency,
            Fixture.ancNotify, Fixture.configNotify, Fixture.getConfigRequest,
            Fixture.getConfigResponse, Fixture.setConfigRequest, Fixture.setConfigResponse,
        ]
        for frame in frames {
            var decoder = FrameDecoder()
            let messages = decoder.feed(hex(frame))
            XCTAssertEqual(messages.count, 1, frame)
            XCTAssertEqual(messages.first?.encode(), hex(frame), frame)
        }
    }

    func testConcatenatedFramesInOneRead() {
        var decoder = FrameDecoder()
        let bytes = hex(Fixture.budsAuthConfirmResponse) + hex(Fixture.budsAuthChallenge) + hex(Fixture.statusNotify1)
        let messages = decoder.feed(bytes)
        XCTAssertEqual(messages.map(\.opcode), [.authConfirm, .authChallenge, .reportStatus])
    }

    func testPartialFramesAreBufferedAtEverySplitPoint() {
        let bytes = hex(Fixture.deviceInfoResponse) + hex(Fixture.statusNotify2)
        for split in 1..<bytes.count {
            var decoder = FrameDecoder()
            var messages = decoder.feed(Array(bytes[..<split]))
            messages += decoder.feed(Array(bytes[split...]))
            XCTAssertEqual(messages.map(\.opcode), [.getDeviceInfo, .reportStatus], "split at \(split)")
        }
    }

    func testByteByByteFeed() {
        var decoder = FrameDecoder()
        var messages: [Message] = []
        for byte in hex(Fixture.getConfigResponse) { messages += decoder.feed([byte]) }
        XCTAssertEqual(messages.count, 1)
    }

    func testResynchronisesAfterGarbage() {
        var decoder = FrameDecoder()
        let bytes = [0x00, 0xef, 0xfe, 0xdc] + hex(Fixture.statusNotify1)
        let messages = decoder.feed(bytes)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].opcode, .reportStatus)
    }

    func testPayloadContainingTrailerByteIsNotTruncated() {
        let message = Message(type: .phoneRequest, opcode: .setConfig, sequence: 1, payload: [0xef, 0xfe, 0xdc, 0xba, 0xef])
        var decoder = FrameDecoder()
        XCTAssertEqual(decoder.feed(message.encode()), [message])
    }

    func testRejectsFrameWithoutTrailerAndRecovers() {
        var broken = hex(Fixture.statusNotify1)
        broken[broken.count - 1] = 0x00
        var decoder = FrameDecoder()
        let messages = decoder.feed(broken + hex(Fixture.statusNotify2))
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].sequence, 0x68)
    }

    func testUnknownOpcodeAndTypeArePreserved() {
        let message = Message(type: .unknown(0x44), opcode: .unknown(0x99), sequence: 3, payload: [1, 2])
        var decoder = FrameDecoder()
        XCTAssertEqual(decoder.feed(message.encode()), [message])
    }
}
