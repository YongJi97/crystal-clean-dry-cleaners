import Foundation

struct PickupDraft: Codable, Equatable {
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var addressLine2: String = ""
    var when: String = ""
    var notes: String = ""

    var isBlank: Bool {
        [name, phone, email, address, addressLine2, when, notes].allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var isSubmittable: Bool {
        PickupValidation.isReady(name: name, phone: phone, address: address, when: when)
    }

    init() {}

    init(
        name: String,
        phone: String,
        email: String = "",
        address: String,
        addressLine2: String = "",
        when: String,
        notes: String = ""
    ) {
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
        self.addressLine2 = addressLine2
        self.when = when
        self.notes = notes
    }

    init(profile: Profile) {
        name = profile.name
        phone = profile.phone
        email = profile.email
        address = profile.address
        addressLine2 = profile.addressLine2
    }

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
