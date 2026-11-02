import Foundation

struct LiveRequestService: RequestService {
    var session: URLSession = .shared

    func submit(draft: PickupDraft, config: RuntimeConfig) async -> SubmitResult {
        async let bridge = postBridge(draft: draft, config: config)
        async let form = postFormspree(draft: draft, config: config)
        let bridgeResult = await bridge
        let formResult = await form
        let succeeded = bridgeResult.ok || formResult.ok
        let reference = bridgeResult.referenceID ?? (succeeded ? Self.localReference() : nil)
        let message = succeeded ? nil : (bridgeResult.message ?? formResult.message ?? "Request failed.")
        return SubmitResult(
            succeeded: succeeded,
            referenceID: reference,
            bridgeOK: bridgeResult.ok,
            formspreeOK: formResult.ok,
            message: message
        )
    }

    private func postBridge(draft: PickupDraft, config: RuntimeConfig) async -> ChannelResult {
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
            let ok = (http?.statusCode ?? 0) < 400 && decoded?.ok == true
            return ChannelResult(
                ok: ok,
                referenceID: decoded?.referenceID,
                message: decoded?.error ?? "The shop ticket service did not accept the request."
            )
        } catch {
            return ChannelResult(ok: false, referenceID: nil, message: "Could not reach the shop.")
        }
    }

    private func postFormspree(draft: PickupDraft, config: RuntimeConfig) async -> ChannelResult {
        let fields = PickupPayload.formFields(draft: draft, isTest: config.isTest)
        let body = PickupPayload.multipartBody(fields: fields)
        var request = URLRequest(url: config.formspreeURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data
        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let decoded = try? JSONDecoder().decode(FormspreeResponse.self, from: data)
            let ok = (http?.statusCode ?? 0) < 400 && decoded?.ok == true
            return ChannelResult(ok: ok, referenceID: nil, message: decoded?.error ?? "Email notification failed.")
        } catch {
            return ChannelResult(ok: false, referenceID: nil, message: "Could not reach the notification service.")
        }
    }

    private static func localReference() -> String {
        let suffix = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(12)
            .lowercased()
        return "local-" + suffix
    }
}

private struct ChannelResult {
    var ok: Bool
    var referenceID: String?
    var message: String?
}

private struct BridgeResponse: Decodable {
    var ok: Bool?
    var referenceID: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case ok, error
        case referenceID = "reference_id"
    }
}

private struct FormspreeResponse: Decodable {
    var ok: Bool?
    var error: String?
}
