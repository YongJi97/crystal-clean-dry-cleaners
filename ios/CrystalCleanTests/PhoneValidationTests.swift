import XCTest
@testable import CrystalClean

final class PhoneValidationTests: XCTestCase {
    func testTenDigitsAndElevenStartingWithOne() {
        XCTAssertTrue(PhoneValidation.isValid("(646) 555-1234"))
        XCTAssertTrue(PhoneValidation.isValid("6465551234"))
        XCTAssertTrue(PhoneValidation.isValid("646-555-1234"))
        XCTAssertTrue(PhoneValidation.isValid("1 (646) 555-1234"))
        XCTAssertTrue(PhoneValidation.isValid("16465551234"))
        XCTAssertTrue(PhoneValidation.isValid("+1 646 555 1234"))
    }

    func testRejectsShortNumbersAndElevenDigitsNotStartingWithOne() {
        XCTAssertFalse(PhoneValidation.isValid(""))
        XCTAssertFalse(PhoneValidation.isValid("555-1234"))
        XCTAssertFalse(PhoneValidation.isValid("646555123"))
        XCTAssertFalse(PhoneValidation.isValid("26465551234"))
        XCTAssertFalse(PhoneValidation.isValid("64655512345"))
    }
}
