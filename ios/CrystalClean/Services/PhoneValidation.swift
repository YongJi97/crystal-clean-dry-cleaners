import Foundation

/// Same rule as request-pickup.html: 10 digits, or 11 digits starting with 1.
enum PhoneValidation {
    static func digits(in value: String) -> String {
        value.filter(\.isNumber)
    }

    static func isValid(_ value: String) -> Bool {
        let digits = digits(in: value)
        if digits.count == 10 {
            return true
        }
        if digits.count == 11, digits.first == "1" {
            return true
        }
        return false
    }
}
