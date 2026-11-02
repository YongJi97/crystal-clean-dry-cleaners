import Foundation

struct StoredRequest: Codable, Equatable, Identifiable {
    var id: String
    var createdAt: Date
    var name: String
    var phone: String
    var email: String
    var address: String
    var addressLine2: String
    var when: String
    var notes: String
    var isTest: Bool

    init(draft: PickupDraft, referenceID: String, isTest: Bool, createdAt: Date = Date()) {
        id = referenceID
        self.createdAt = createdAt
        name = PickupDraft.trimmed(draft.name)
        phone = PickupDraft.trimmed(draft.phone)
        email = PickupDraft.trimmed(draft.email)
        address = PickupDraft.trimmed(draft.address)
        addressLine2 = PickupDraft.trimmed(draft.addressLine2)
        when = PickupDraft.trimmed(draft.when)
        notes = PickupDraft.trimmed(draft.notes)
        self.isTest = isTest
    }

    /// Fields to copy back into the pickup form. This is the text the customer
    /// typed, without the `[TEST]` name prefix added on the wire.
    var draft: PickupDraft {
        PickupDraft(
            name: name,
            phone: phone,
            email: email,
            address: address,
            addressLine2: addressLine2,
            when: when,
            notes: notes
        )
    }
}
