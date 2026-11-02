import Foundation

protocol ProfileStoring {
    func load() -> Profile
    func save(_ profile: Profile)
}

struct UserDefaultsProfileStore: ProfileStoring {
    var defaults: UserDefaults
    var key: String

    init(defaults: UserDefaults = .standard, key: String = "crystalclean.profile") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> Profile {
        guard let data = defaults.data(forKey: key) else { return Profile() }
        return (try? JSONDecoder().decode(Profile.self, from: data)) ?? Profile()
    }

    func save(_ profile: Profile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }
}

final class MemoryProfileStore: ProfileStoring {
    var profile = Profile()

    func load() -> Profile { profile }

    func save(_ profile: Profile) {
        self.profile = profile
    }
}
