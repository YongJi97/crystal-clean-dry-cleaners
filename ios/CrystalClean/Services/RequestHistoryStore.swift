import Foundation

protocol RequestHistoryStoring {
    func load() -> [StoredRequest]
    func save(_ requests: [StoredRequest])
}

struct FileRequestHistoryStore: RequestHistoryStoring {
    var fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = base.appendingPathComponent("CrystalClean", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("requests.json")
        }
    }

    func load() -> [StoredRequest] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([StoredRequest].self, from: data)) ?? []
    }

    func save(_ requests: [StoredRequest]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(requests) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class MemoryHistoryStore: RequestHistoryStoring {
    var requests: [StoredRequest] = []

    func load() -> [StoredRequest] { requests }

    func save(_ requests: [StoredRequest]) {
        self.requests = requests
    }
}
