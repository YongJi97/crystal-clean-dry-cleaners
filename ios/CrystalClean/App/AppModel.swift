import Foundation
import Observation

enum AppTab: Hashable {
    case services
    case pickup
    case requests
    case profile
}

@MainActor
@Observable
final class AppModel {
    var selectedTab: AppTab = .services
    var catalog: ServiceCatalog
    var profile: Profile
    var pickupDraft = PickupDraft()
    var history: [StoredRequest]
    var isSubmitting = false
    var submitError: String?
    var showConfirmation = false
    var lastReferenceID = ""
    var draftRevision = 0
    var pickupDate = PickupSchedule.defaultDate()

    let config: RuntimeConfig
    private let requests: RequestService
    private let catalogProvider: CatalogProviding
    private let profileStore: ProfileStoring
    private let historyStore: RequestHistoryStoring
    private let notifier: PickupNotifying

    init(
        config: RuntimeConfig = .resolve(),
        requests: RequestService? = nil,
        catalogProvider: CatalogProviding? = nil,
        profileStore: ProfileStoring = UserDefaultsProfileStore(),
        historyStore: RequestHistoryStoring = FileRequestHistoryStore(),
        notifier: PickupNotifying = SystemPickupNotifier(),
        launchArguments: [String] = CommandLine.arguments
    ) {
        self.config = config
        self.requests = requests ?? (config.useMock ? MockRequestService() : LiveRequestService())
        self.catalogProvider = catalogProvider ?? CatalogService()
        self.profileStore = profileStore
        self.historyStore = historyStore
        self.notifier = notifier
        profile = profileStore.load()
        history = historyStore.load()
        catalog = self.catalogProvider.bundledCatalog()
        #if DEBUG
        DebugLaunch.apply(self, arguments: launchArguments)
        #else
        _ = launchArguments
        #endif
    }

    func loadCatalog() async {
        catalog = await catalogProvider.load()
    }

    /// NavigationStack ignores a confirmation that is already presented at launch.
    /// Toggle it once the pickup screen appears so `-showConfirmation` can push.
    func replayConfirmationIfNeeded() {
        guard showConfirmation else { return }
        let reference = lastReferenceID
        showConfirmation = false
        Task { @MainActor in
            lastReferenceID = reference
            showConfirmation = true
        }
    }

    func preparePickupForm() {
        // Fill from the profile only while the form is still empty, so a later
        // profile edit shows up, and a reorder or in-progress draft is kept.
        if pickupDraft.isBlank {
            pickupDraft = PickupDraft(profile: profile)
        }
    }

    func reorder(_ request: StoredRequest) {
        var draft = request.draft
        draft.when = ""
        pickupDraft = draft
        pickupDate = PickupSchedule.defaultDate()
        showConfirmation = false
        submitError = nil
        draftRevision += 1
        selectedTab = .pickup
    }

    func saveProfile() {
        profileStore.save(profile)
    }

    func clearMyData() {
        profile = Profile()
        profileStore.save(profile)
        history = []
        historyStore.save([])
        pickupDraft = PickupDraft()
        pickupDate = PickupSchedule.defaultDate()
        showConfirmation = false
        submitError = nil
    }

    func submitPickup() async {
        guard !isSubmitting else { return }
        pickupDraft.when = PickupSchedule.format(pickupDate)
        guard pickupDate >= Date().addingTimeInterval(-60) else {
            submitError = "Choose a future pickup time."
            return
        }
        guard pickupDraft.isSubmittable else {
            submitError = "Enter your name, a valid phone number, the pickup address, and a time."
            return
        }
        isSubmitting = true
        submitError = nil
        let draft = pickupDraft
        let result = await requests.submit(draft: draft, config: config)
        isSubmitting = false
        guard result.succeeded, let referenceID = result.referenceID else {
            submitError = result.message ?? "We couldn't send the request. Call 646-338-6883."
            return
        }
        let stored = StoredRequest(
            draft: draft,
            referenceID: referenceID,
            isTest: config.isTest
        )
        history.insert(stored, at: 0)
        historyStore.save(history)
        notifier.notifySubmitted(referenceID: referenceID)
        lastReferenceID = referenceID
        showConfirmation = true
    }
}
