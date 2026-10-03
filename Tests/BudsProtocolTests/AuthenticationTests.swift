import XCTest
@testable import BudsProtocol

final class AuthenticationTests: XCTestCase {
    /// The earbuds challenged the phone with an all-zero random block; the phone answered with `answerFromPhone`.
    func testAnswerToAllZeroChallengeMatchesCapture() {
        let answer = Authentication.computeResponse(to: [UInt8](repeating: 0, count: 16))
        XCTAssertEqual(answer, hex(Fixture.answerFromPhone))
    }

    /// The phone challenged the earbuds; the earbuds answered with `answerFromBuds`.
    func testAnswerToPhoneChallengeMatchesEarbudsCapture() {
        let answer = Authentication.computeResponse(to: hex(Fixture.challengeFromPhone))
        XCTAssertEqual(answer, hex(Fixture.answerFromBuds))
    }

    func testRandomChallengeHasBlockSize() {
        XCTAssertEqual(Authentication.randomChallenge().count, 16)
    }

    func testResponseIsDeterministic() {
        let challenge = hex(Fixture.challengeFromPhone)
        XCTAssertEqual(Authentication.computeResponse(to: challenge), Authentication.computeResponse(to: challenge))
    }
}
