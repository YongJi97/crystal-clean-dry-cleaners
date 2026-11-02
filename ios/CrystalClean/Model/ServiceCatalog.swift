import Foundation

struct ServiceCatalog: Codable, Equatable {
    var currency: String
    var categories: [ServiceCategory]
}

struct ServiceCategory: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var subtitle: String?
    var icon: String?
    var layout: String?
    var summary: String?
    var detail: String?
    var notes: String?
    var homeTitle: String?
    var fromPrice: ServicePriceFrom?
    var items: [ServiceItem]

    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, icon, layout, summary, detail, notes, items
        case homeTitle
        case fromPrice = "from"
    }
}

struct ServicePriceFrom: Codable, Equatable {
    var label: String
    var price: Double
    var unit: String?
}

struct ServiceItem: Codable, Equatable, Identifiable {
    var name: String
    var price: Double
    var unit: String?
    var notes: String?

    var id: String { name }
}

enum PriceFormat {
    static func dollars(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    static func line(_ item: ServiceItem) -> String {
        if item.unit == "lb" {
            return "\(dollars(item.price)) / lb"
        }
        return dollars(item.price)
    }
}
