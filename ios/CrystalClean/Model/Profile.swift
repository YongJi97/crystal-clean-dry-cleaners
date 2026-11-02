import Foundation

struct Profile: Codable, Equatable {
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var addressLine2: String = ""
}
