import Foundation

struct MockRequestService: RequestService {
    func submit(draft: PickupDraft, config: RuntimeConfig) async -> SubmitResult {
        _ = try? PickupPayload.bridgeObject(draft: draft, isTest: config.isTest)
        let suffix = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(12)
            .lowercased()
        let prefix = config.isTest ? "test-" : "mock-"
        return SubmitResult(
            succeeded: true,
            referenceID: prefix + suffix,
            squareOK: true,
            notifyOK: true,
            message: nil
        )
    }
}
