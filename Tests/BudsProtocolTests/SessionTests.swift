import XCTest
@testable import BudsProtocol

final class SessionTests: XCTestCase {
    private func makeSession() -> BudsSession {
        BudsSession(challenge: { hex(Fixture.challengeFromPhone) })
    }

    func testBeginSendsAuthChallenge() {
        var session = makeSession()
        XCTAssertEqual(session.begin(), [hex(Fixture.phoneAuthChallenge)])
    }

    /// Replays the captured handshake and checks every frame the phone sent.
    func testFullHandshakeReplay() {
        var session = makeSession()
        _ = session.begin()

        var out = session.receive(hex(Fixture.budsAuthResponse))
        XCTAssertEqual(out.outgoing, [hex(Fixture.phoneAuthConfirm)])

        out = session.receive(hex(Fixture.budsAuthConfirmResponse))
        XCTAssertTrue(out.outgoing.isEmpty)

        out = session.receive(hex(Fixture.budsAuthChallenge))
        XCTAssertEqual(out.outgoing, [hex(Fixture.phoneAuthAnswer)])

        out = session.receive(hex(Fixture.budsAuthConfirm))
        XCTAssertEqual(out.outgoing.first, hex(Fixture.phoneAuthConfirmReply))
        XCTAssertEqual(out.outgoing[1], hex(Fixture.deviceInfoRequest))
        XCTAssertEqual(out.outgoing[2], hex("fedcbac409000503ffffffffef"))
        XCTAssertEqual(out.events, [.authenticated])
        // One GET_CONFIG frame per initial configuration request.
        XCTAssertEqual(out.outgoing.count, 3 + ConfigCode.initialRequests.count)
    }

    func testHandshakeWithConcatenatedBudsFrames() {
        var session = makeSession()
        _ = session.begin()
        _ = session.receive(hex(Fixture.budsAuthResponse))
        let out = session.receive(hex(Fixture.budsAuthConfirmResponse) + hex(Fixture.budsAuthChallenge))
        XCTAssertEqual(out.outgoing, [hex(Fixture.phoneAuthAnswer)])
    }

    func testDeviceInfoResponseEmitsEvent() {
        var session = makeSession()
        let out = session.receive(hex(Fixture.deviceInfoResponse))
        guard case .deviceInfo(let info)? = out.events.first else { return XCTFail("expected device info") }
        XCTAssertEqual(info.name, "REDMI Buds 8")
        XCTAssertTrue(out.outgoing.isEmpty)
    }

    func testStatusNotificationIsAcknowledgedWithSameSequence() {
        var session = makeSession()
        let out = session.receive(hex(Fixture.statusNotify1))
        XCTAssertEqual(out.outgoing, [hex("fedcba040e000200" + "60" + "ef")])
        guard case .status(let updates)? = out.events.first else { return XCTFail("expected status") }
        XCTAssertEqual(updates.count, 1)
    }

    func testConfigNotificationIsAcknowledged() {
        var session = makeSession()
        let out = session.receive(hex(Fixture.configNotify))
        XCTAssertEqual(out.outgoing, [hex("fedcba04f4000200" + "71" + "ef")])
        XCTAssertEqual(out.events, [.config([.noiseModeChanged(mode: .off, strength: 0)])])
    }

    func testResponsesToCommandsAreNotAcknowledgedAgain() {
        var session = makeSession()
        let out = session.receive(hex(Fixture.setConfigResponse))
        XCTAssertTrue(out.outgoing.isEmpty)
        XCTAssertEqual(out.events, [.commandAcknowledged(.setConfig)])
    }

    func testGetConfigResponseEmitsConfigEvent() {
        var session = makeSession()
        let out = session.receive(hex(Fixture.getConfigResponse))
        guard case .config(let updates)? = out.events.first else { return XCTFail("expected config") }
        XCTAssertEqual(updates.count, 2)
    }

    func testUnknownFrameIsSurfaced() {
        var session = makeSession()
        let frame = Message(type: .earbudsNotify, opcode: .unknown(0x77), sequence: 9, payload: [1]).encode()
        let out = session.receive(frame)
        XCTAssertEqual(out.events.count, 1)
        guard case .unhandled(let message)? = out.events.first else { return XCTFail("expected unhandled") }
        XCTAssertEqual(message.opcode, .unknown(0x77))
    }

    func testCommandsContinueSequenceAfterHandshake() {
        var session = makeSession()
        _ = session.begin()                       // seq 0
        _ = session.receive(hex(Fixture.budsAuthResponse)) // seq 1
        let frames = session.send(.setNoiseMode(.transparency))
        XCTAssertEqual(frames, [hex("fedcbac408000402" + "020402" + "ef")])
    }
}
