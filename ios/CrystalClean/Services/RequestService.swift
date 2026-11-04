import Foundation

protocol RequestService {
    func submit(draft: PickupDraft, config: RuntimeConfig) async -> SubmitResult
}

struct SubmitResult: Equatable {
    var succeeded: Bool
    var referenceID: String?
    var squareOK: Bool
    var notifyOK: Bool
    var message: String?
}
