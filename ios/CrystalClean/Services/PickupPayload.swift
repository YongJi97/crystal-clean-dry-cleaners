import Foundation

enum PickupPayload {
    static let testSubject = "[TEST] Pickup request — please ignore"
    static let testNamePrefix = "[TEST] "

    static func markedName(_ name: String, isTest: Bool) -> String {
        let trimmed = PickupDraft.trimmed(name)
        guard isTest else { return trimmed }
        if trimmed.hasPrefix("[TEST]") {
            return trimmed
        }
        return testNamePrefix + trimmed
    }

    static func bridgeEndpoint(base: URL) -> URL {
        base.appending(path: "webhooks").appending(path: "formspree-pickup")
    }

    static func bridgeBody(draft: PickupDraft, isTest: Bool) -> BridgeBody {
        BridgeBody(
            name: markedName(draft.name, isTest: isTest),
            phone: PickupDraft.trimmed(draft.phone),
            email: PickupDraft.trimmed(draft.email),
            address: PickupDraft.trimmed(draft.address),
            addressLine2: PickupDraft.trimmed(draft.addressLine2),
            whenText: PickupDraft.trimmed(draft.when),
            notes: PickupDraft.trimmed(draft.notes),
            includeTestFlag: isTest
        )
    }

    static func bridgeObject(draft: PickupDraft, isTest: Bool) throws -> [String: Any] {
        let data = try JSONEncoder().encode(bridgeBody(draft: draft, isTest: isTest))
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    static func formFields(draft: PickupDraft, isTest: Bool) -> [(name: String, value: String)] {
        var fields: [(name: String, value: String)] = [
            ("name", markedName(draft.name, isTest: isTest)),
            ("phone", PickupDraft.trimmed(draft.phone)),
            ("email", PickupDraft.trimmed(draft.email)),
            ("address", PickupDraft.trimmed(draft.address)),
            ("address_line2", PickupDraft.trimmed(draft.addressLine2)),
            ("when", PickupDraft.trimmed(draft.when)),
            ("notes", PickupDraft.trimmed(draft.notes)),
        ]
        if isTest {
            fields.append(("_subject", testSubject))
        }
        return fields
    }

    static func bridgeHeaders(isTest: Bool, appAPIKey: String) -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]
        let key = appAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            headers["X-App-Key"] = key
        }
        if isTest {
            headers["X-Test"] = "1"
        }
        return headers
    }

    static func multipartBody(fields: [(name: String, value: String)]) -> (data: Data, contentType: String) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var data = Data()
        for field in fields {
            data.append(utf8: "--\(boundary)\r\n")
            data.append(utf8: "Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            data.append(utf8: field.value)
            data.append(utf8: "\r\n")
        }
        data.append(utf8: "--\(boundary)--\r\n")
        return (data, "multipart/form-data; boundary=\(boundary)")
    }
}

struct BridgeBody: Encodable, Equatable {
    var name: String
    var phone: String
    var email: String
    var address: String
    var addressLine2: String
    var whenText: String
    var notes: String
    var includeTestFlag: Bool

    enum CodingKeys: String, CodingKey {
        case name, phone, email, address, notes
        case addressLine2 = "address_line2"
        case whenText = "when"
        case includeTestFlag = "is_test"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encode(email, forKey: .email)
        try container.encode(address, forKey: .address)
        try container.encode(addressLine2, forKey: .addressLine2)
        try container.encode(whenText, forKey: .whenText)
        try container.encode(notes, forKey: .notes)
        if includeTestFlag {
            try container.encode(true, forKey: .includeTestFlag)
        }
    }
}

private extension Data {
    mutating func append(utf8 string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
