import MapKit
import SwiftUI
import UIKit

struct ShopCard: View {
    var shop: ShopInfo
    @State private var showMapChooser = false

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
                Button {
                    ShopContactActions.call(url, openURL: { UIApplication.shared.open($0) })
                } label: {
                    Label("Call \(shop.displayPhone)", systemImage: "phone")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
            if ShopMaps.query(for: shop) != nil {
                Button {
                    ShopContactActions.chooseMap(presentMapChoices: { showMapChooser = true })
                } label: {
                    Label("Open in Maps", systemImage: "map")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .confirmationDialog("Open in Maps", isPresented: $showMapChooser, titleVisibility: .visible) {
            Button("Apple Maps") { ShopMaps.openApple(shop) }
            Button("Google Maps") { ShopMaps.openGoogle(shop) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

enum ShopContactActions {
    static func call(_ url: URL, openURL: (URL) -> Void) {
        openURL(url)
    }

    static func chooseMap(presentMapChoices: () -> Void) {
        presentMapChoices()
    }
}

enum ShopMaps {
    static func query(for shop: ShopInfo) -> String? {
        let address = shop.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !address.isEmpty { return address }
        if let latitude = shop.latitude, let longitude = shop.longitude {
            return "\(latitude),\(longitude)"
        }
        return nil
    }

    static func googleMapsURL(address: String, googleAppInstalled: Bool) -> URL? {
        guard let encoded = encodeQuery(address) else { return nil }
        if googleAppInstalled {
            return URL(string: "comgooglemaps://?q=\(encoded)")
        }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)")
    }

    static func openApple(_ shop: ShopInfo) {
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

    static func openGoogle(
        _ shop: ShopInfo,
        canOpenGoogleApp: (URL) -> Bool = { UIApplication.shared.canOpenURL($0) },
        open: (URL) -> Void = { UIApplication.shared.open($0) }
    ) {
        guard let address = query(for: shop), let probe = URL(string: "comgooglemaps://") else { return }
        guard let url = googleMapsURL(address: address, googleAppInstalled: canOpenGoogleApp(probe)) else { return }
        open(url)
    }

    private static func encodeQuery(_ address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return trimmed.addingPercentEncoding(withAllowedCharacters: allowed)
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
                Button("Need to change or cancel? Call us") {
                    ShopContactActions.call(url, openURL: { UIApplication.shared.open($0) })
                }
                .font(.body)
                .buttonStyle(.borderless)
                Text(shown)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
