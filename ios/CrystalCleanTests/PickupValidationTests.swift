import XCTest
@testable import CrystalClean

final class PickupValidationTests: XCTestCase {
    func testRequiredFieldsMatchTheWebsite() {
        XCTAssertTrue(
            PickupValidation.isReady(
                name: "Ada Lovelace",
                phone: "(646) 555-1234",
                address: "400 E 87th Street",
                when: "Tomorrow 10am"
            )
        )
        XCTAssertTrue(
            PickupValidation.isReady(
                name: "  Ada  ",
                phone: "1 (646) 555-1234",
                address: " 400 E 87th Street ",
                when: " ASAP "
            )
        )
    }

    func testOptionalFieldsAreNotRequired() {
        XCTAssertNil(PickupValidation.nameIssue("Ada"))
        XCTAssertNil(PickupValidation.phoneIssue("6465551234"))
        XCTAssertNil(PickupValidation.addressIssue("400 E 87th Street"))
        XCTAssertNil(PickupValidation.whenIssue("Tomorrow 10am"))
        XCTAssertTrue(
            PickupValidation.isReady(
                name: "Ada",
                phone: "6465551234",
                address: "400 E 87th Street",
                when: "Tomorrow 10am"
            )
        )
    }

    func testEmptyRequiredFieldsUseTheWebsiteMessages() {
        XCTAssertEqual(PickupValidation.nameIssue("   "), PickupValidation.nameMessage)
        XCTAssertEqual(PickupValidation.nameIssue(""), "Please enter your name.")
        XCTAssertEqual(PickupValidation.phoneIssue(""), PickupValidation.phoneMessage)
        XCTAssertEqual(PickupValidation.phoneIssue("555"), "Please enter a valid 10-digit phone number.")
        XCTAssertEqual(PickupValidation.phoneIssue("26465551234"), PickupValidation.phoneMessage)
        XCTAssertEqual(PickupValidation.addressIssue(" "), "Please enter your pickup address.")
        XCTAssertEqual(PickupValidation.whenIssue(""), "Please tell us when you\u{2019}d like pickup.")
        XCTAssertFalse(
            PickupValidation.isReady(name: "", phone: "6465551234", address: "400 E 87th", when: "Tomorrow")
        )
        XCTAssertFalse(
            PickupValidation.isReady(name: "Ada", phone: "555", address: "400 E 87th", when: "Tomorrow")
        )
        XCTAssertFalse(
            PickupValidation.isReady(name: "Ada", phone: "6465551234", address: "", when: "Tomorrow")
        )
        XCTAssertFalse(
            PickupValidation.isReady(name: "Ada", phone: "6465551234", address: "400 E 87th", when: "")
        )
    }
}
