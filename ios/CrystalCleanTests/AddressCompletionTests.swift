import XCTest
@testable import CrystalClean

final class AddressCompletionTests: XCTestCase {
    func testFormatsTitleAndSubtitleIntoOneAddress() {
        XCTAssertEqual(
            AddressCompletionFormat.address(
                title: "400 E 87th Street",
                subtitle: "New York, NY"
            ),
            "400 E 87th Street, New York, NY"
        )
    }

    func testDropsEmptyPartsAndAvoidsRepeatingTheTitle() {
        XCTAssertEqual(AddressCompletionFormat.address(title: "400 E 87th Street", subtitle: "  "), "400 E 87th Street")
        XCTAssertEqual(AddressCompletionFormat.address(title: "", subtitle: "New York, NY"), "New York, NY")
        XCTAssertEqual(
            AddressCompletionFormat.address(
                title: "400 E 87th Street",
                subtitle: "400 E 87th Street, New York, NY 10128"
            ),
            "400 E 87th Street, New York, NY 10128"
        )
    }
}
