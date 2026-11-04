import Foundation

protocol CatalogProviding {
    func bundledCatalog() -> ServiceCatalog
    func load() async -> ServiceCatalog
}

struct CatalogService: CatalogProviding {
    var remoteURL: URL
    var cacheURL: URL
    var session: URLSession
    var bundle: Bundle

    init(
        remoteURL: URL = URL(string: "https://www.crystalcleandrycleaner.com/data/services.json")!,
        cacheURL: URL? = nil,
        session: URLSession = .shared,
        bundle: Bundle = .main
    ) {
        self.remoteURL = remoteURL
        self.session = session
        self.bundle = bundle
        if let cacheURL {
            self.cacheURL = cacheURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = base.appendingPathComponent("CrystalClean", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.cacheURL = directory.appendingPathComponent("services.json")
        }
    }

    func bundledCatalog() -> ServiceCatalog {
        guard
            let url = bundle.url(forResource: "services", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(ServiceCatalog.self, from: data)
        else {
            return ServiceCatalog(currency: "USD", categories: [])
        }
        return catalog
    }

    func load() async -> ServiceCatalog {
        if let data = await fetchData(),
           let catalog = try? JSONDecoder().decode(ServiceCatalog.self, from: data) {
            try? data.write(to: cacheURL, options: .atomic)
            return catalog
        }
        if let data = try? Data(contentsOf: cacheURL),
           let catalog = try? JSONDecoder().decode(ServiceCatalog.self, from: data) {
            return catalog
        }
        return bundledCatalog()
    }

    private func fetchData() async -> Data? {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}

struct EmptyCatalogService: CatalogProviding {
    func bundledCatalog() -> ServiceCatalog {
        ServiceCatalog(currency: "USD", categories: [])
    }

    func load() async -> ServiceCatalog {
        bundledCatalog()
    }
}
