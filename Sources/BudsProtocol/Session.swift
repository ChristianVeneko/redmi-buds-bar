public enum BudsEvent: Equatable, Sendable {
    /// The earbuds confirmed authentication; initial info requests were queued for sending.
    case authenticated
    case deviceInfo(DeviceInfo)
    case runInfo(RunInfo)
    case status([StatusUpdate])
    case config([ConfigUpdate])
    /// A response to a command we sent (ANC / SET_CONFIG).
    case commandAcknowledged(Opcode)
    /// A frame this implementation does not interpret; log it.
    case unhandled(Message)
}

public struct SessionOutput: Equatable, Sendable {
    public var outgoing: [[UInt8]] = []
    public var events: [BudsEvent] = []

    public init(outgoing: [[UInt8]] = [], events: [BudsEvent] = []) {
        self.outgoing = outgoing
        self.events = events
    }
}

/// Pure protocol state machine: feed it received bytes, send what it returns.
/// The handshake mirrors Gadgetbridge: the phone challenges first, then answers the earbuds' challenge.
public struct BudsSession: Sendable {
    private var decoder = FrameDecoder()
    private var builder = CommandBuilder()
    private let makeChallenge: @Sendable () -> [UInt8]

    public init(challenge: @escaping @Sendable () -> [UInt8] = { Authentication.randomChallenge() }) {
        self.makeChallenge = challenge
    }

    /// Frames to send right after the RFCOMM channel opened.
    public mutating func begin() -> [[UInt8]] {
        decoder = FrameDecoder()
        builder = CommandBuilder()
        let challenge = makeChallenge()
        let message = builder.message(.authChallenge, payload: [0x01] + challenge)
        return [message.encode()]
    }

    public mutating func send(_ command: Command) -> [[UInt8]] {
        builder.frames(command)
    }

    public mutating func receive(_ bytes: [UInt8]) -> SessionOutput {
        var output = SessionOutput()
        for message in decoder.feed(bytes) {
            handle(message, into: &output)
        }
        return output
    }

    private func acknowledge(_ message: Message) -> [UInt8] {
        Message(type: .response, opcode: message.opcode, sequence: message.sequence).encode()
    }

    private mutating func handle(_ message: Message, into output: inout SessionOutput) {
        switch message.opcode {
        case .authChallenge:
            if message.type == .response {
                // The earbuds' answer is not verified (same as Gadgetbridge).
                output.outgoing.append(builder.message(.authConfirm, payload: [0x01, 0x00]).encode())
            } else if message.payload.count >= 17 {
                let answer = Authentication.computeResponse(to: Array(message.payload[1..<17]))
                output.outgoing.append(
                    Message(type: .response, opcode: .authChallenge, sequence: message.sequence,
                            payload: [0x01] + answer).encode()
                )
            } else {
                output.events.append(.unhandled(message))
            }
        case .authConfirm:
            if message.type.isRequest {
                output.outgoing.append(
                    Message(type: .response, opcode: .authConfirm, sequence: message.sequence, payload: [0x01]).encode()
                )
                output.outgoing += builder.frames(.requestDeviceInfo)
                output.outgoing += builder.frames(.requestRunInfo)
                output.outgoing += builder.frames(.requestConfig(ConfigCode.initialRequests))
                output.events.append(.authenticated)
            }
        case .getDeviceInfo:
            output.events.append(.deviceInfo(DeviceInfo.parse(message.payload)))
        case .getDeviceRunInfo:
            output.events.append(.runInfo(RunInfo.parse(message.payload)))
        case .reportStatus:
            output.events.append(.status(StatusUpdate.parse(message.payload)))
            if message.type.isRequest { output.outgoing.append(acknowledge(message)) }
        case .getConfig:
            output.events.append(.config(ConfigUpdate.parse(message.payload, isNotification: false)))
        case .notifyConfig:
            output.events.append(.config(ConfigUpdate.parse(message.payload, isNotification: true)))
            if message.type.isRequest { output.outgoing.append(acknowledge(message)) }
        case .anc, .setConfig:
            if message.type == .response {
                output.events.append(.commandAcknowledged(message.opcode))
            } else {
                output.events.append(.unhandled(message))
            }
        case .unknown:
            output.events.append(.unhandled(message))
        }
    }
}
