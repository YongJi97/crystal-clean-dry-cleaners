import Foundation
import UserNotifications

protocol PickupNotifying {
    func notifySubmitted(referenceID: String)
}

struct SystemPickupNotifier: PickupNotifying {
    func notifySubmitted(referenceID: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Pickup request received"
            content.body = "Reference \(referenceID)"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "pickup-\(referenceID)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}

struct NoopNotifier: PickupNotifying {
    func notifySubmitted(referenceID: String) {}
}

final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
