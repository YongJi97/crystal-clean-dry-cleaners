import XCTest
@testable import CrystalClean

final class ServiceCatalogTests: XCTestCase {
    func testBundledServicesJSONDecodesSitePrices() throws {
        let bundle = Bundle(for: ServiceCatalogTests.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "services", withExtension: "json"),
            "services.json must be copied into the CrystalCleanTests resources"
        )
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(ServiceCatalog.self, from: data)

        XCTAssertEqual(catalog.currency, "USD")
        XCTAssertEqual(catalog.categories.map(\.id), [
            "dry-cleaning", "wash-fold", "laundered-shirts", "tailoring",
        ])

        let dry = try XCTUnwrap(catalog.categories.first { $0.id == "dry-cleaning" })
        XCTAssertEqual(dry.fromPrice?.label, "From")
        XCTAssertEqual(dry.fromPrice?.price, 6.5)
        XCTAssertEqual(dry.items.first?.name, "Sweaters")
        XCTAssertEqual(dry.items.first?.price, 6.5)
        XCTAssertEqual(dry.items.first?.unit, "item")
        XCTAssertEqual(dry.items.map(\.name).count, 12)

        let wash = try XCTUnwrap(catalog.categories.first { $0.id == "wash-fold" })
        XCTAssertEqual(wash.fromPrice?.label, "Per lb")
        XCTAssertEqual(wash.fromPrice?.price, 1)
        XCTAssertEqual(wash.fromPrice?.unit, "lb")
        XCTAssertEqual(wash.items.first?.unit, "lb")
        XCTAssertEqual(wash.notes, "10 lb minimum per order")

        let shirts = try XCTUnwrap(catalog.categories.first { $0.id == "laundered-shirts" })
        XCTAssertEqual(shirts.homeTitle, "Laundered Shirts")
        XCTAssertEqual(shirts.fromPrice?.price, 2)
        XCTAssertEqual(shirts.items.first { $0.name == "Hanger" }?.price, 3.25)

        let tailoring = try XCTUnwrap(catalog.categories.first { $0.id == "tailoring" })
        XCTAssertEqual(tailoring.fromPrice?.label, "From")
        XCTAssertEqual(tailoring.fromPrice?.price, 15)
        XCTAssertEqual(tailoring.items.first { $0.name == "Pants Hem" }?.price, 15)
        XCTAssertEqual(tailoring.items.first { $0.name == "Pants Zipper" }?.price, 20)
        XCTAssertEqual(tailoring.notes, "Other alterations? Ask us for a quote.")

        XCTAssertEqual(PriceFormat.line(wash.items[0]), "$1.00 / lb")
        XCTAssertEqual(PriceFormat.dollars(6.5), "$6.50")
    }
}
