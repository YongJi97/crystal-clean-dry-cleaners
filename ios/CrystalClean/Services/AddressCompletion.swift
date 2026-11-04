import CoreLocation
import Foundation
import MapKit

enum AddressCompletionFormat {
    /// Street from the completion title, place from the subtitle: "400 E 87th Street, New York, NY".
    static func address(title: String, subtitle: String) -> String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return subtitle }
        if subtitle.isEmpty { return title }
        if subtitle.localizedCaseInsensitiveContains(title) { return subtitle }
        return "\(title), \(subtitle)"
    }
}

enum ShopRegion {
    /// 400 E 87th Street, New York, NY 10128.
    static let latitude = 40.7777
    static let longitude = -73.9528
    static let spanDegrees = 0.2

    static var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)
        )
    }
}

struct AddressSuggestion: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String

    var formattedAddress: String {
        AddressCompletionFormat.address(title: title, subtitle: subtitle)
    }
}

final class AddressCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [AddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var lockedQuery: String?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = ShopRegion.region
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lockedQuery, trimmed == lockedQuery { return }
        lockedQuery = nil
        guard !trimmed.isEmpty else {
            suggestions = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func accept(_ formatted: String) {
        lockedQuery = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestions = []
        completer.queryFragment = ""
    }

    func dismissSuggestions() {
        suggestions = []
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.prefix(5).enumerated().map { index, result in
            AddressSuggestion(
                id: "\(index)|\(result.title)|\(result.subtitle)",
                title: result.title,
                subtitle: result.subtitle
            )
        }
        publish(Array(mapped))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        publish([])
    }

    private func publish(_ suggestions: [AddressSuggestion]) {
        if Thread.isMainThread {
            self.suggestions = suggestions
        } else {
            DispatchQueue.main.async { self.suggestions = suggestions }
        }
    }
}
