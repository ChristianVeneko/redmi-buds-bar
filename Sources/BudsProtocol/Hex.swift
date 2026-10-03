/// Hex helpers used for logging and tests.
public enum Hex {
    /// Parses a hex string (whitespace ignored). Returns nil for malformed input.
    public static func bytes(_ string: String) -> [UInt8]? {
        let digits = string.filter { !$0.isWhitespace }
        guard digits.count % 2 == 0 else { return nil }
        var result: [UInt8] = []
        result.reserveCapacity(digits.count / 2)
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            guard let byte = UInt8(digits[index..<next], radix: 16) else { return nil }
            result.append(byte)
            index = next
        }
        return result
    }

    public static func string(_ bytes: [UInt8]) -> String {
        let digits = Array("0123456789abcdef")
        var result = ""
        result.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            result.append(digits[Int(byte >> 4)])
            result.append(digits[Int(byte & 0x0F)])
        }
        return result
    }
}

public extension Array where Element == UInt8 {
    var hexString: String { Hex.string(self) }
}
