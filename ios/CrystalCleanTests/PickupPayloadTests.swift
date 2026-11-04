import XCTest
@testable import CrystalClean

final class PickupPayloadTests: XCTestCase {
    private var draft: PickupDraft {
        PickupDraft(
            name: " Ada ",
            phone: " 646-555-1234 ",
            email: " ada@example.com ",
            address: " 400 E 87th Street ",
            addressLine2: " Apt 4B ",
            when: " Tomorrow 10am ",
            notes: " Buzz "
        )
    }

    func testLivePayloadMatchesTheSevenSiteFields() throws {
        let object = try PickupPayload.bridgeObject(draft: draft, isTest: false)
        XCTAssertEqual(object["name"] as? String, "Ada")
        XCTAssertEqual(object["phone"] as? String, "646-555-1234")
        XCTAssertEqual(object["email"] as? String, "ada@example.com")
        XCTAssertEqual(object["address"] as? String, "400 E 87th Street")
        XCTAssertEqual(object["address_line2"] as? String, "Apt 4B")
        XCTAssertEqual(object["when"] as? String, "Tomorrow 10am")
        XCTAssertEqual(object["notes"] as? String, "Buzz")
        XCTAssertNil(object["is_test"])
        XCTAssertEqual(
            Set(object.keys),
            ["name", "phone", "email", "address", "address_line2", "when", "notes"]
        )

        let fields = Dictionary(uniqueKeysWithValues: PickupPayload.formFields(draft: draft, isTest: false))
        XCTAssertNil(fields["_subject"])
        XCTAssertEqual(fields["name"], "Ada")

        let headers = PickupPayload.bridgeHeaders(isTest: false, appAPIKey: "")
        XCTAssertEqual(headers["Accept"], "application/json")
        XCTAssertEqual(headers["Content-Type"], "application/json")
        XCTAssertNil(headers["X-Test"])
        XCTAssertNil(headers["X-App-Key"])
    }

    func testTestModeMarksNameSubjectAndBridgeFlag() throws {
        XCTAssertEqual(
            PickupPayload.testSubject,
            "[TEST] Pickup request — please ignore"
        )

        let object = try PickupPayload.bridgeObject(draft: draft, isTest: true)
        XCTAssertEqual(object["name"] as? String, "[TEST] Ada")
        XCTAssertEqual(object["is_test"] as? Bool, true)
        XCTAssertEqual(object["phone"] as? String, "646-555-1234")

        let fields = Dictionary(uniqueKeysWithValues: PickupPayload.formFields(draft: draft, isTest: true))
        XCTAssertEqual(fields["name"], "[TEST] Ada")
        XCTAssertEqual(fields["_subject"], PickupPayload.testSubject)
        XCTAssertTrue(fields["_subject"]?.hasPrefix("[TEST]") == true)

        XCTAssertEqual(PickupPayload.markedName("[TEST] Ada", isTest: true), "[TEST] Ada")
        XCTAssertEqual(PickupPayload.markedName("[TEST]Ada", isTest: true), "[TEST]Ada")

        let headers = PickupPayload.bridgeHeaders(isTest: true, appAPIKey: "secret")
        XCTAssertEqual(headers["X-Test"], "1")
        XCTAssertEqual(headers["X-App-Key"], "secret")
        XCTAssertEqual(headers["Accept"], "application/json")
    }

    func testBridgeEndpointUsesTheWebhookPath() {
        let endpoint = PickupPayload.bridgeEndpoint(base: URL(string: "http://localhost:3015")!)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:3015/webhooks/formspree-pickup")
        let production = PickupPayload.bridgeEndpoint(base: RuntimeConfig.productionBridge)
        XCTAssertEqual(
            production.absoluteString,
            "https://www.crystalcleandrycleaner.com/webhooks/formspree-pickup"
        )
    }

    func testRuntimeModes() {
        let debug = RuntimeConfig.resolve(arguments: [], info: [:], isDebug: true)
        XCTAssertTrue(debug.useMock)
        XCTAssertTrue(debug.isTest)

        let local = RuntimeConfig.resolve(
            arguments: ["App", "-useLocalBridge"],
            info: ["APP_API_KEY": "abc"],
            isDebug: true
        )
        XCTAssertFalse(local.useMock)
        XCTAssertTrue(local.isTest)
        XCTAssertEqual(local.bridgeBaseURL, RuntimeConfig.localBridge)
        XCTAssertEqual(local.appAPIKey, "abc")

        let release = RuntimeConfig.resolve(arguments: [], info: [:], isDebug: false)
        XCTAssertFalse(release.useMock)
        XCTAssertFalse(release.isTest)
        XCTAssertEqual(release.bridgeBaseURL, RuntimeConfig.productionBridge)

        let testMode = RuntimeConfig.resolve(arguments: ["-testMode"], info: [:], isDebug: false)
        XCTAssertFalse(testMode.useMock)
        XCTAssertFalse(testMode.isTest)
        XCTAssertEqual(testMode.bridgeBaseURL, RuntimeConfig.productionBridge)

        let debugTest = RuntimeConfig.resolve(arguments: ["-testMode"], info: [:], isDebug: true)
        XCTAssertFalse(debugTest.useMock)
        XCTAssertTrue(debugTest.isTest)
        XCTAssertEqual(debugTest.formspreeURL, RuntimeConfig.formspree)

        let releaseLocal = RuntimeConfig.resolve(arguments: ["-useLocalBridge"], info: [:], isDebug: false)
        XCTAssertFalse(releaseLocal.isTest)
        XCTAssertEqual(releaseLocal.bridgeBaseURL, RuntimeConfig.productionBridge)

        XCTAssertEqual(RuntimeConfig.appAPIKey(from: ["APP_API_KEY": "$(APP_API_KEY)"]), "")
        XCTAssertEqual(RuntimeConfig.appAPIKey(from: ["APP_API_KEY": "  "]), "")
    }
}
