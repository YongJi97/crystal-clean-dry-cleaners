import XCTest
@testable import CrystalClean

final class ShopMapsTests: XCTestCase {
    func testGoogleMapsUsesTheAppURLWhenInstalled() {
        let address = "400 E 87th Street, New York, NY 10128"
        let url = ShopMaps.googleMapsURL(address: address, googleAppInstalled: true)
        XCTAssertEqual(
            url?.absoluteString,
            "comgooglemaps://?q=400%20E%2087th%20Street,%20New%20York,%20NY%2010128"
        )
    }

    func testGoogleMapsFallsBackToTheWebURL() {
        let url = ShopMaps.googleMapsURL(address: "400 E 87th Street", googleAppInstalled: false)
        XCTAssertEqual(
            url?.absoluteString,
            "https://www.google.com/maps/search/?api=1&query=400%20E%2087th%20Street"
        )
    }

    func testGoogleQueryEncodesCharactersThatWouldSplitTheQuery() {
        let url = ShopMaps.googleMapsURL(address: "A & B", googleAppInstalled: true)
        XCTAssertEqual(url?.absoluteString, "comgooglemaps://?q=A%20%26%20B")
        XCTAssertNil(ShopMaps.googleMapsURL(address: "   ", googleAppInstalled: false))
    }

    func testOpenGooglePicksTheInstalledAppOrTheWebsite() {
        let shop = ShopInfo(address: "400 E 87th Street")
        var opened: [URL] = []
        ShopMaps.openGoogle(shop, canOpenGoogleApp: { _ in true }, open: { opened.append($0) })
        ShopMaps.openGoogle(shop, canOpenGoogleApp: { _ in false }, open: { opened.append($0) })
        XCTAssertEqual(opened.map(\.scheme), ["comgooglemaps", "https"])
        XCTAssertTrue(opened[0].absoluteString.hasPrefix("comgooglemaps://?q="))
        XCTAssertTrue(opened[1].absoluteString.hasPrefix("https://www.google.com/maps/search/?api=1&query="))
    }

    func testQueryPrefersTheStreetAddress() {
        let both = ShopInfo(address: "400 E 87th Street", latitude: 40.7777, longitude: -73.9528)
        XCTAssertEqual(ShopMaps.query(for: both), "400 E 87th Street")
        let pinOnly = ShopInfo(latitude: 40.7777, longitude: -73.9528)
        XCTAssertEqual(ShopMaps.query(for: pinOnly), "\(40.7777),\(-73.9528)")
        XCTAssertNil(ShopMaps.query(for: ShopInfo()))
    }
}
