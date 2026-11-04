import Foundation
import UIKit
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
            if let logo = Self.logoAttachment() {
                content.attachments = [logo]
            }
            let request = UNNotificationRequest(
                identifier: "pickup-\(referenceID)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    /// The banner uses this file so the alert shows the crystal icon, not a bundled badge.
    private static func logoAttachment() -> UNNotificationAttachment? {
        guard let image = UIImage(named: "Logo"), let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("crystal-clean-logo.png")
        do {
            try data.write(to: url, options: .atomic)
            return try UNNotificationAttachment(identifier: "logo", url: url)
        } catch {
            return nil
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
