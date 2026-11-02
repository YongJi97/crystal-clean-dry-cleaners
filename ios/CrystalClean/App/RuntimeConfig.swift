import Foundation

struct RuntimeConfig: Equatable {
    var useMock: Bool
    var bridgeBaseURL: URL
    var formspreeURL: URL
    var isTest: Bool
    var appAPIKey: String

    static let formspree = URL(string: "https://formspree.io/f/mjgewqpz")!
    static let productionBridge = URL(string: "https://www.crystalcleandrycleaner.com")!
    static let localBridge = URL(string: "http://localhost:3015")!

    static let mock = RuntimeConfig(
        useMock: true,
        bridgeBaseURL: localBridge,
        formspreeURL: formspree,
        isTest: true,
        appAPIKey: ""
    )

    static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func resolve(
        arguments: [String] = CommandLine.arguments,
        info: [String: Any] = Bundle.main.infoDictionary ?? [:],
        isDebug: Bool = isDebugBuild
    ) -> RuntimeConfig {
        let key = appAPIKey(from: info)
        let testMode = arguments.contains("-testMode")
        let local = arguments.contains("-useLocalBridge")

        if isDebug && local {
            return RuntimeConfig(
                useMock: false,
                bridgeBaseURL: localBridge,
                formspreeURL: formspree,
                isTest: true,
                appAPIKey: key
            )
        }
        if testMode {
            return RuntimeConfig(
                useMock: false,
                bridgeBaseURL: productionBridge,
                formspreeURL: formspree,
                isTest: true,
                appAPIKey: key
            )
        }
        if isDebug {
            return RuntimeConfig(
                useMock: true,
                bridgeBaseURL: localBridge,
                formspreeURL: formspree,
                isTest: true,
                appAPIKey: key
            )
        }
        return RuntimeConfig(
            useMock: false,
            bridgeBaseURL: productionBridge,
            formspreeURL: formspree,
            isTest: false,
            appAPIKey: key
        )
    }

    static func appAPIKey(from info: [String: Any]) -> String {
        let raw = (info["APP_API_KEY"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty || raw.contains("$(") {
            return ""
        }
        return raw
    }
}
