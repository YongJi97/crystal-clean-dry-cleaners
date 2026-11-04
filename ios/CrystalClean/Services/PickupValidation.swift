import Foundation

/// Required fields match request-pickup.html: name, phone, address, and when.
/// Email, address line 2, and notes are optional and are not checked here.
enum PickupValidation {
    static let nameMessage = "Please enter your name."
    static let phoneMessage = "Please enter a valid 10-digit phone number."
    static let addressMessage = "Please enter your pickup address."
    static let whenMessage = "Please tell us when you\u{2019}d like pickup."

    static func nameIssue(_ value: String) -> String? {
        PickupDraft.trimmed(value).isEmpty ? nameMessage : nil
    }

    static func phoneIssue(_ value: String) -> String? {
        PhoneValidation.isValid(value) ? nil : phoneMessage
    }

    static func addressIssue(_ value: String) -> String? {
        PickupDraft.trimmed(value).isEmpty ? addressMessage : nil
    }

    static func whenIssue(_ value: String) -> String? {
        PickupDraft.trimmed(value).isEmpty ? whenMessage : nil
    }

    static func isReady(name: String, phone: String, address: String, when: String) -> Bool {
        nameIssue(name) == nil
            && phoneIssue(phone) == nil
            && addressIssue(address) == nil
            && whenIssue(when) == nil
    }
}
