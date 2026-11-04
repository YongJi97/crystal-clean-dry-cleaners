import XCTest

final class InfoPlistTests: XCTestCase {
    /// xcodegen rewrites Info.plist from project.yml. These two keys are the ones
    /// a partial properties block dropped: the app key (401 on submit) and the display name.
    func testBundleInfoPlistKeepsTheAPIKeyAndDisplayName() {
        let info = Bundle.main.infoDictionary
        // The value may be empty in CI, where no secret is configured. The key must still exist.
        XCTAssertNotNil(info?["APP_API_KEY"])
        XCTAssertEqual(info?["CFBundleDisplayName"] as? String, "Crystal Clean")
    }
}
