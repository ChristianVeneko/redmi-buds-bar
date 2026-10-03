import BudsProtocol

/// Frames captured from a real REDMI Buds 8 session (hex).
enum Fixture {
    static let phoneAuthChallenge = "fedcbac4500012000167c6697351ff4aec29cdbaabf2fbe346ef"
    static let budsAuthResponse = "fedcba0450001300000112953ffa34f0b875cd3b6850b974856cef"
    static let phoneAuthConfirm = "fedcbac4510003010100ef"
    static let budsAuthConfirmResponse = "fedcba04510003000101ef"
    static let budsAuthChallenge = "fedcbac05000125d0100000000000000000000000000000000ef"
    static let phoneAuthAnswer = "fedcba04500013005d01bca5905bc849392e7bf9fdcdc570ef77ef"
    static let budsAuthConfirm = "fedcbac05100035e0100ef"
    static let phoneAuthConfirmReply = "fedcba04510003005e01ef"
    static let deviceInfoRequest = "fedcbac402000502ffffffffef"
    static let deviceInfoResponse =
        "fedcba0402003c00020d005245444d49204275647320380501520252020503271750f30204010205000407dede4f020800020900020a01020b01020d01020e03020f01ef"
    static let statusNotify1 = "fedcbac70e0006600400dede4fef"
    static let statusNotify2 = "fedcbac70e00066804005f5effef"
    static let statusNotify3 = "fedcbac70e00067b04005e5dffef"
    static let ancOff = "fedcbac40800040a020400ef"
    static let ancOn = "fedcbac40800040b020401ef"
    static let ancTransparency = "fedcbac40800040d020402ef"
    static let ancNotify = "fedcbac70e000470020400ef"
    static let configNotify = "fedcbac7f400067104000b0000ef"
    static let getConfigRequest = "fedcbac4f30005100002000aef"
    static let getConfigResponse = "fedcba04f30019001011000201010102030303060604080805000004000a0606ef"
    static let setConfigRequest = "fedcbac4f20007110500020402ffef"
    static let setConfigResponse = "fedcba04f200020011ef"

    static let challengeFromPhone = "67c6697351ff4aec29cdbaabf2fbe346"
    static let answerFromBuds = "12953ffa34f0b875cd3b6850b974856c"
    static let answerFromPhone = "bca5905bc849392e7bf9fdcdc570ef77"
}

func hex(_ string: String) -> [UInt8] {
    guard let bytes = Hex.bytes(string) else { fatalError("invalid hex: \(string)") }
    return bytes
}
