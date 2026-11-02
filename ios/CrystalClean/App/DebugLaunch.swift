import Foundation

/// Debug-only launch arguments for screenshots. Release builds do not call this.
enum DebugLaunch {
    static let demoProfile = Profile(
        name: "[TEST] Demo",
        phone: "(646) 555-0100",
        email: "demo@example.com",
        address: "123 Example Street, New York, NY 10001",
        addressLine2: "Demo"
    )

    static let demoRequest = StoredRequest(
        draft: PickupDraft(
            name: "[TEST] Demo",
            phone: "(646) 555-0100",
            email: "demo@example.com",
            address: "123 Example Street, New York, NY 10001",
            addressLine2: "Demo",
            when: "Tomorrow 10am",
            notes: "Fake request for screenshots"
        ),
        referenceID: "test-demo",
        isTest: true,
        createdAt: Date(timeIntervalSince1970: 1_730_000_000)
    )

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

    @MainActor
    static func apply(_ model: AppModel, arguments: [String]) {
        if seedsDemo(arguments) {
            model.profile = demoProfile
            model.history = [demoRequest]
        }
        if let tab = startTab(from: arguments) {
            model.selectedTab = tab
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
