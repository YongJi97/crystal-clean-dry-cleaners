import MapKit
import SwiftUI

struct ShopCard: View {
    var shop: ShopInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image("Logo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text(shop.name ?? "Crystal Clean Dry Cleaners")
                    .font(.headline)
            }
            if let hours = trimmed(shop.hours) {
                Label(hours, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let address = trimmed(shop.address) {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let url = shop.callURL, !shop.displayPhone.isEmpty {
                Link(destination: url) {
                    Label("Call \(shop.displayPhone)", systemImage: "phone")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if trimmed(shop.address) != nil || (shop.latitude != nil && shop.longitude != nil) {
                Button {
                    ShopMaps.open(shop)
                } label: {
                    Label("Open in Maps", systemImage: "map")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

enum ShopMaps {
    static func open(_ shop: ShopInfo) {
        let name = shop.name ?? "Crystal Clean Dry Cleaners"
        if let latitude = shop.latitude, let longitude = shop.longitude {
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            let item = MKMapItem(placemark: placemark)
            item.name = name
            item.openInMaps()
            return
        }
        guard let address = shop.address, !address.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        MKLocalSearch(request: request).start { response, _ in
            guard let item = response?.mapItems.first else { return }
            item.name = name
            DispatchQueue.main.async {
                item.openInMaps()
            }
        }
    }
}

struct CallShopLink: View {
    var shop: ShopInfo?

    private var digits: String {
        let fromShop = shop?.phone?.filter(\.isNumber) ?? ""
        return fromShop.isEmpty ? "6463386883" : fromShop
    }

    private var shown: String {
        let fromShop = shop?.displayPhone ?? ""
        return fromShop.isEmpty ? "646-338-6883" : fromShop
    }

    var body: some View {
        if let url = URL(string: "tel:\(digits)") {
            VStack(alignment: .leading, spacing: 2) {
                Link("Need to change or cancel? Call us", destination: url)
                    .font(.body)
                Text(shown)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
