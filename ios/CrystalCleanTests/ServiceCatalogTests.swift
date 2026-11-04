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

        let shop = try XCTUnwrap(catalog.shop)
        XCTAssertEqual(shop.phone, "6463386883")
        XCTAssertEqual(shop.phoneDisplay, "646-338-6883")
        XCTAssertEqual(shop.address, "400 E 87th Street, New York, NY 10128")
        XCTAssertEqual(shop.hours, "Mon–Sat · 7:30 AM – 7:00 PM")
        XCTAssertEqual(shop.latitude, 40.7777)
        XCTAssertEqual(shop.longitude, -73.9528)
        XCTAssertEqual(
            shirts.items.first { $0.name == "Hanger" }?.notes,
            "Returned on a hanger instead of folded."
        )
    }

    func testCatalogWithoutShopStillDecodes() throws {
        let json = #"{"currency":"USD","categories":[]}"#
        let catalog = try JSONDecoder().decode(ServiceCatalog.self, from: Data(json.utf8))
        XCTAssertNil(catalog.shop)
    }

    func testExplainersSearchAndConfirmationCopy() throws {
        let bare = ServiceItem(name: "Hand Press", price: 6, unit: "item", notes: nil)
        XCTAssertEqual(ItemExplainers.detail(for: bare), "Pressed by hand for a sharper finish.")

        let json = """
        {"currency":"USD","categories":[{"id":"shirts","name":"Shirts","items":[{"name":"Hand Press","price":6,"unit":"item"},{"name":"Sheets","price":15,"unit":"item"}]}]}
        """
        let catalog = try JSONDecoder().decode(ServiceCatalog.self, from: Data(json.utf8))
        let matches = ServiceSearch.filter(catalog.categories, query: "hand")
        XCTAssertEqual(matches.first?.items.map(\.name), ["Hand Press"])

        XCTAssertEqual(ConfirmationCopy.title(for: "test-abc"), "Request received")
        XCTAssertEqual(
            ConfirmationCopy.title(for: "local-abc123"),
            "Saved — call if you don't hear back"
        )
        XCTAssertNil(ConfirmationCopy.referenceLabel(for: "local-abc123"))
        let long = String(repeating: "a", count: 30)
        XCTAssertEqual(ConfirmationCopy.referenceLabel(for: long), String(repeating: "a", count: 12))
        XCTAssertGreaterThan(PickupSchedule.defaultDate(), Date())
        XCTAssertFalse(PickupSchedule.format(PickupSchedule.defaultDate()).isEmpty)
    }
}
