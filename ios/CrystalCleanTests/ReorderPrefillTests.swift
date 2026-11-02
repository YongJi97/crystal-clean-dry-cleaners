import XCTest
@testable import CrystalClean

@MainActor
final class ReorderPrefillTests: XCTestCase {
    func testReorderCopiesEveryFieldIntoTheForm() {
        let model = makeModel()
        model.showConfirmation = true
        model.selectedTab = .requests
        let stored = sampleRequest()

        model.reorder(stored)

        XCTAssertEqual(model.pickupDraft, stored.draft)
        XCTAssertEqual(model.pickupDraft.name, "Ada Lovelace")
        XCTAssertEqual(model.pickupDraft.phone, "6465551234")
        XCTAssertEqual(model.pickupDraft.email, "ada@example.com")
        XCTAssertEqual(model.pickupDraft.address, "400 E 87th Street")
        XCTAssertEqual(model.pickupDraft.addressLine2, "Apt 4B")
        XCTAssertEqual(model.pickupDraft.when, "Tomorrow 10am")
        XCTAssertEqual(model.pickupDraft.notes, "Buzz 4B")
        XCTAssertEqual(model.selectedTab, .pickup)
        XCTAssertFalse(model.showConfirmation)
        XCTAssertFalse(model.pickupDraft.name.hasPrefix("[TEST]"))
    }

    func testPrepareFillsABlankFormFromTheProfileAndReorderWins() {
        let profiles = MemoryProfileStore()
        profiles.profile = Profile(
            name: "Pat",
            phone: "6465559999",
            email: "pat@example.com",
            address: "1 Main Street",
            addressLine2: "2F"
        )
        let model = makeModel(profileStore: profiles)
        model.preparePickupForm()
        XCTAssertEqual(model.pickupDraft.name, "Pat")
        XCTAssertEqual(model.pickupDraft.phone, "6465559999")
        XCTAssertEqual(model.pickupDraft.addressLine2, "2F")
        XCTAssertEqual(model.pickupDraft.when, "")

        model.reorder(sampleRequest())
        model.preparePickupForm()
        XCTAssertEqual(model.pickupDraft.name, "Ada Lovelace")
        XCTAssertEqual(model.pickupDraft.address, "400 E 87th Street")
    }

    func testSubmitKeepsTheTypedNameAndReferenceForReorder() async throws {
        let service = ScriptedRequestService(
            result: SubmitResult(
                succeeded: true,
                referenceID: "test-abc123def456",
                bridgeOK: true,
                formspreeOK: false,
                message: nil
            )
        )
        let history = MemoryHistoryStore()
        let notifier = RecordingNotifier()
        let model = makeModel(requests: service, historyStore: history, notifier: notifier)
        model.pickupDraft = PickupDraft(
            name: "Ada Lovelace",
            phone: "(646) 555-1234",
            email: "ada@example.com",
            address: "400 E 87th Street",
            addressLine2: "Apt 4B",
            when: "Tomorrow 10am",
            notes: "Buzz 4B"
        )

        await model.submitPickup()

        let stored = try XCTUnwrap(model.history.first)
        XCTAssertEqual(stored.name, "Ada Lovelace")
        XCTAssertEqual(stored.isTest, true)
        XCTAssertEqual(stored.id, "test-abc123def456")
        XCTAssertEqual(model.lastReferenceID, "test-abc123def456")
        XCTAssertTrue(model.showConfirmation)
        XCTAssertEqual(notifier.references, ["test-abc123def456"])
        XCTAssertEqual(history.requests.first?.id, "test-abc123def456")

        model.pickupDraft = PickupDraft()
        model.reorder(model.history[0])
        XCTAssertEqual(model.pickupDraft.name, "Ada Lovelace")
        XCTAssertEqual(model.pickupDraft.phone, "(646) 555-1234")
    }

    func testInvalidPhoneDoesNotSubmit() async {
        let service = ScriptedRequestService(
            result: SubmitResult(succeeded: true, referenceID: "should-not-send", bridgeOK: true, formspreeOK: true, message: nil)
        )
        service.onSubmit = { XCTFail("invalid phone must not be submitted") }
        let model = makeModel(requests: service)
        model.pickupDraft = PickupDraft(name: "Ada", phone: "555", address: "400 E 87th", when: "Tomorrow")

        await model.submitPickup()

        XCTAssertTrue(model.history.isEmpty)
        XCTAssertFalse(model.showConfirmation)
        XCTAssertNotNil(model.submitError)
    }

    func testDebugLaunchArgsSeedADemoAndSelectATab() {
        XCTAssertEqual(DebugLaunch.startTab(from: ["-startTab", "requests"]), .requests)
        XCTAssertEqual(DebugLaunch.startTab(from: ["-startTab", "profile"]), .profile)
        XCTAssertEqual(DebugLaunch.startTab(from: ["-startTab services"]), .services)
        XCTAssertEqual(DebugLaunch.startTab(from: ["-startTab=pickup"]), .pickup)
        XCTAssertNil(DebugLaunch.startTab(from: ["-startTab", "nope"]))
        XCTAssertFalse(DebugLaunch.seedsDemo([]))

        let seeded = makeModel(launchArguments: ["-seedDemo", "-startTab", "requests"])
        XCTAssertEqual(seeded.selectedTab, .requests)
        XCTAssertEqual(seeded.history.map(\.name), ["[TEST] Demo"])
        XCTAssertEqual(seeded.history.first?.id, "test-demo")
        XCTAssertEqual(seeded.profile.name, "[TEST] Demo")
        XCTAssertEqual(seeded.profile.email, "demo@example.com")
        XCTAssertTrue(PhoneValidation.isValid(seeded.profile.phone))

        let plain = makeModel(launchArguments: [])
        XCTAssertTrue(plain.history.isEmpty)
        XCTAssertEqual(plain.selectedTab, .services)
        XCTAssertEqual(plain.profile.name, "")
    }

    private func makeModel(
        requests: RequestService = MockRequestService(),
        profileStore: ProfileStoring = MemoryProfileStore(),
        historyStore: RequestHistoryStoring = MemoryHistoryStore(),
        notifier: PickupNotifying = NoopNotifier(),
        launchArguments: [String] = []
    ) -> AppModel {
        AppModel(
            config: .mock,
            requests: requests,
            catalogProvider: EmptyCatalogService(),
            profileStore: profileStore,
            historyStore: historyStore,
            notifier: notifier,
            launchArguments: launchArguments
        )
    }

    private func sampleRequest() -> StoredRequest {
        StoredRequest(
            draft: PickupDraft(
                name: "Ada Lovelace",
                phone: "6465551234",
                email: "ada@example.com",
                address: "400 E 87th Street",
                addressLine2: "Apt 4B",
                when: "Tomorrow 10am",
                notes: "Buzz 4B"
            ),
            referenceID: "test-sample",
            isTest: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

private final class ScriptedRequestService: RequestService {
    var result: SubmitResult
    var onSubmit: () -> Void = {}

    init(result: SubmitResult) {
        self.result = result
    }

    func submit(draft: PickupDraft, config: RuntimeConfig) async -> SubmitResult {
        onSubmit()
        return result
    }
}

private final class RecordingNotifier: PickupNotifying {
    var references: [String] = []

    func notifySubmitted(referenceID: String) {
        references.append(referenceID)
    }
}
