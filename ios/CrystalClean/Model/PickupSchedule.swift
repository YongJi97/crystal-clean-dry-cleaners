import Foundation

enum PickupSchedule {
    static func defaultDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(24 * 60 * 60)
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    /// Text stored in the bridge `when` field. The server still receives a string.
    static func format(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }
}

enum ShopAlertCopy {
    /// Shown when the Square ticket exists but the shop alert did not send.
    /// A second submit would create another ticket, so this does not ask them to try again.
    static let notifyFailed = "We saved this pickup, but the shop alert did not go through. Call 646-338-6883 to confirm. Please don't send it again."
}

enum ConfirmationCopy {
    static func isUncertain(_ referenceID: String) -> Bool {
        referenceID.hasPrefix("local-") || referenceID.count > 24
    }

    static func title(for referenceID: String) -> String {
        if isUncertain(referenceID) {
            return "Saved — call if you don't hear back"
        }
        return "Request received"
    }

    static func referenceLabel(for referenceID: String) -> String? {
        if referenceID.hasPrefix("local-") {
            return nil
        }
        if referenceID.count > 24 {
            return String(referenceID.prefix(12))
        }
        return referenceID
    }
}
