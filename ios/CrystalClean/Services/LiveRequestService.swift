import Foundation

struct LiveRequestService: RequestService {
    var session: URLSession = .shared

    func submit(draft: PickupDraft, config: RuntimeConfig) async -> SubmitResult {
        let bridge = await postBridge(draft: draft, config: config)
        let full = bridge.squareOK && bridge.notifyOK
        return SubmitResult(
            succeeded: full,
            referenceID: bridge.referenceID,
            squareOK: bridge.squareOK,
            notifyOK: bridge.notifyOK,
            message: full || bridge.squareOK ? nil : bridge.message
        )
    }

    private func postBridge(draft: PickupDraft, config: RuntimeConfig) async -> BridgeOutcome {
        let endpoint = PickupPayload.bridgeEndpoint(base: config.bridgeBaseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        let headers = PickupPayload.bridgeHeaders(isTest: config.isTest, appAPIKey: config.appAPIKey)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        do {
            request.httpBody = try JSONEncoder().encode(PickupPayload.bridgeBody(draft: draft, isTest: config.isTest))
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let decoded = try? JSONDecoder().decode(BridgeResponse.self, from: data)
            let httpOK = (http?.statusCode ?? 0) < 400
            let squareOK = httpOK && decoded?.squareOK == true
            let notifyOK = httpOK && decoded?.notifyOK == true
            let message = squareOK ? nil : (decoded?.error ?? "The shop ticket service did not accept the request.")
            return BridgeOutcome(
                squareOK: squareOK,
                notifyOK: notifyOK,
                referenceID: decoded?.referenceID,
                message: message
            )
        } catch {
            return BridgeOutcome(squareOK: false, notifyOK: false, referenceID: nil, message: "Could not reach the shop.")
        }
    }
}

private struct BridgeOutcome {
    var squareOK: Bool
    var notifyOK: Bool
    var referenceID: String?
    var message: String?
}

private struct BridgeResponse: Decodable {
    var ok: Bool?
    var squareOK: Bool?
    var notifyOK: Bool?
    var referenceID: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case ok, error
        case squareOK = "square_ok"
        case notifyOK = "notify_ok"
        case referenceID = "reference_id"
    }
}
