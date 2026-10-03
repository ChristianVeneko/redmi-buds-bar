/// Direction/kind of a frame. Types with bit 0x40 set carry no status byte.
public enum MessageType: Equatable, Sendable {
    case phoneRequest      // 0xC4
    case response          // 0x04
    case earbudsRequest    // 0xC0
    case earbudsNotify     // 0xC7
    case unknown(UInt8)

    public init(code: UInt8) {
        switch code {
        case 0xC4: self = .phoneRequest
        case 0x04: self = .response
        case 0xC0: self = .earbudsRequest
        case 0xC7: self = .earbudsNotify
        default: self = .unknown(code)
        }
    }

    public var code: UInt8 {
        switch self {
        case .phoneRequest: 0xC4
        case .response: 0x04
        case .earbudsRequest: 0xC0
        case .earbudsNotify: 0xC7
        case .unknown(let code): code
        }
    }

    /// Requests and notifications omit the status byte that precedes the sequence number in responses.
    public var isRequest: Bool { code & 0x40 != 0 }
}

public enum Opcode: Equatable, Sendable {
    case getDeviceInfo     // 0x02
    case anc               // 0x08
    case getDeviceRunInfo  // 0x09
    case reportStatus      // 0x0E
    case authChallenge     // 0x50
    case authConfirm       // 0x51
    case setConfig         // 0xF2
    case getConfig         // 0xF3
    case notifyConfig      // 0xF4
    case unknown(UInt8)

    public init(code: UInt8) {
        switch code {
        case 0x02: self = .getDeviceInfo
        case 0x08: self = .anc
        case 0x09: self = .getDeviceRunInfo
        case 0x0E: self = .reportStatus
        case 0x50: self = .authChallenge
        case 0x51: self = .authConfirm
        case 0xF2: self = .setConfig
        case 0xF3: self = .getConfig
        case 0xF4: self = .notifyConfig
        default: self = .unknown(code)
        }
    }

    public var code: UInt8 {
        switch self {
        case .getDeviceInfo: 0x02
        case .anc: 0x08
        case .getDeviceRunInfo: 0x09
        case .reportStatus: 0x0E
        case .authChallenge: 0x50
        case .authConfirm: 0x51
        case .setConfig: 0xF2
        case .getConfig: 0xF3
        case .notifyConfig: 0xF4
        case .unknown(let code): code
        }
    }
}

/// One protocol frame: `FE DC BA | type | opcode | length(2, BE) | [status] | seq | payload | EF`.
/// The length field counts the optional status byte, the sequence byte and the payload.
public struct Message: Equatable, Sendable {
    public static let header: [UInt8] = [0xFE, 0xDC, 0xBA]
    public static let trailer: UInt8 = 0xEF

    public var type: MessageType
    public var opcode: Opcode
    public var sequence: UInt8
    public var payload: [UInt8]

    public init(type: MessageType, opcode: Opcode, sequence: UInt8, payload: [UInt8] = []) {
        self.type = type
        self.opcode = opcode
        self.sequence = sequence
        self.payload = payload
    }

    public func encode() -> [UInt8] {
        let extra = type.isRequest ? 1 : 2
        let length = payload.count + extra
        var bytes = Message.header
        bytes.reserveCapacity(payload.count + 9)
        bytes.append(type.code)
        bytes.append(opcode.code)
        bytes.append(UInt8((length >> 8) & 0xFF))
        bytes.append(UInt8(length & 0xFF))
        if !type.isRequest { bytes.append(0x00) }
        bytes.append(sequence)
        bytes.append(contentsOf: payload)
        bytes.append(Message.trailer)
        return bytes
    }
}

/// Streaming frame decoder. Handles concatenated frames, frames split across reads and stray bytes.
public struct FrameDecoder: Sendable {
    /// Frames announcing a longer body than this are treated as corrupt.
    static let maxBodyLength = 4096
    private static let fixedPrefix = 7 // header(3) + type + opcode + length(2)

    private var buffer: [UInt8] = []
    /// Number of bytes dropped while resynchronising (diagnostics).
    public private(set) var discardedByteCount = 0

    public init() {}

    public mutating func feed(_ bytes: [UInt8]) -> [Message] {
        buffer.append(contentsOf: bytes)
        var messages: [Message] = []

        while true {
            guard let start = headerIndex() else {
                // Keep a possible partial header at the tail.
                let keep = min(buffer.count, Message.header.count - 1)
                let drop = buffer.count - keep
                if drop > 0 { discard(drop) }
                break
            }
            if start > 0 { discard(start) }
            guard buffer.count >= Self.fixedPrefix else { break }

            let type = MessageType(code: buffer[3])
            let length = Int(buffer[5]) << 8 | Int(buffer[6])
            let minimum = type.isRequest ? 1 : 2
            guard length >= minimum, length <= Self.maxBodyLength else {
                discard(1) // corrupt header; resynchronise on the next candidate
                continue
            }
            let total = Self.fixedPrefix + length + 1
            guard buffer.count >= total else { break } // wait for the rest

            guard buffer[total - 1] == Message.trailer else {
                discard(1)
                continue
            }
            let bodyStart = Self.fixedPrefix + (type.isRequest ? 0 : 1)
            let sequence = buffer[bodyStart]
            let payload = Array(buffer[(bodyStart + 1)..<(total - 1)])
            messages.append(Message(type: type, opcode: Opcode(code: buffer[4]), sequence: sequence, payload: payload))
            buffer.removeFirst(total)
        }
        return messages
    }

    private func headerIndex() -> Int? {
        guard buffer.count >= 3 else { return nil }
        for i in 0...(buffer.count - 3)
        where buffer[i] == 0xFE && buffer[i + 1] == 0xDC && buffer[i + 2] == 0xBA {
            return i
        }
        return nil
    }

    private mutating func discard(_ count: Int) {
        buffer.removeFirst(count)
        discardedByteCount += count
    }
}
