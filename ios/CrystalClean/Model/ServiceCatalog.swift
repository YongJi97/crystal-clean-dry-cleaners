import Foundation

struct ServiceCatalog: Codable, Equatable {
    var currency: String
    var categories: [ServiceCategory]
    var shop: ShopInfo?
}

struct ShopInfo: Codable, Equatable {
    var name: String?
    var phone: String?
    var phoneDisplay: String?
    var address: String?
    var hours: String?
    var latitude: Double?
    var longitude: Double?

    var callURL: URL? {
        let digits = (phone ?? "").filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }

    var displayPhone: String {
        (phoneDisplay ?? phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ItemExplainers {
    private static let builtin = [
        "Hanger": "Returned on a hanger instead of folded.",
        "Box": "Folded and packed in a box.",
        "Hand Press": "Pressed by hand for a sharper finish.",
    ]

    static func detail(for item: ServiceItem) -> String? {
        if let notes = item.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            return notes
        }
        return builtin[item.name]
    }
}

enum ServiceSearch {
    static func filter(_ categories: [ServiceCategory], query: String) -> [ServiceCategory] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return categories }
        return categories.compactMap { category in
            if category.name.localizedCaseInsensitiveContains(trimmed) {
                return category
            }
            let items = category.items.filter { item in
                item.name.localizedCaseInsensitiveContains(trimmed)
                    || (ItemExplainers.detail(for: item)?.localizedCaseInsensitiveContains(trimmed) ?? false)
            }
            guard !items.isEmpty else { return nil }
            var copy = category
            copy.items = items
            return copy
        }
    }
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
