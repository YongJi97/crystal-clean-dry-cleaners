import Foundation

/// Debug-only launch arguments for screenshots. Release builds do not call this.
enum DebugLaunch {
    static let demoWhen = "Tomorrow 10am"

    static let demoProfile = Profile(
        name: "[TEST] Demo",
        phone: "(646) 555-0100",
        email: "demo@example.com",
        address: "123 Example Street, New York, NY 10001",
        addressLine2: "Apt 2B"
    )

    static var demoCreatedAt: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())
            ?? Date().addingTimeInterval(-24 * 60 * 60)
    }

    static var demoRequest: StoredRequest {
        StoredRequest(
            draft: demoDraft,
            referenceID: "test-demo",
            isTest: true,
            createdAt: demoCreatedAt
        )
    }

    static var demoDraft: PickupDraft {
        PickupDraft(
            name: "[TEST] Demo",
            phone: "(646) 555-0100",
            email: "demo@example.com",
            address: "123 Example Street, New York, NY 10001",
            addressLine2: "Apt 2B",
            when: demoWhen,
            notes: "Fake request for screenshots"
        )
    }

    static func startTab(from arguments: [String]) -> AppTab? {
        guard let raw = value(for: "-startTab", in: arguments)?.lowercased() else { return nil }
        switch raw {
        case "services": return .services
        case "pickup": return .pickup
        case "requests": return .requests
        case "profile": return .profile
        default: return nil
        }
    }

    static func seedsDemo(_ arguments: [String]) -> Bool {
        arguments.contains("-seedDemo")
    }

    static func showsConfirmation(_ arguments: [String]) -> Bool {
        arguments.contains("-showConfirmation")
    }

    @MainActor
    static func apply(_ model: AppModel, arguments: [String]) {
        let request = demoRequest
        if seedsDemo(arguments) {
            model.profile = demoProfile
            model.history = [request]
            model.pickupDraft = request.draft
        }
        if let tab = startTab(from: arguments) {
            model.selectedTab = tab
        }
        if showsConfirmation(arguments) {
            model.lastReferenceID = request.id
            model.showConfirmation = true
            model.selectedTab = .pickup
            if model.pickupDraft.isBlank {
                model.pickupDraft = request.draft
            }
        }
    }

    /// Accepts `-startTab requests`, `-startTab=requests`, or one token `-startTab requests`.
    private static func value(for flag: String, in arguments: [String]) -> String? {
        for (index, argument) in arguments.enumerated() {
            if argument == flag, arguments.indices.contains(index + 1) {
                let next = arguments[index + 1]
                if !next.hasPrefix("-") {
                    return next
                }
            }
            if argument.hasPrefix(flag + "=") {
                let value = String(argument.dropFirst(flag.count + 1))
                if !value.isEmpty { return value }
            }
            if argument.hasPrefix(flag + " ") {
                let value = argument.dropFirst(flag.count + 1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }
}
