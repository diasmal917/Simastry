import Foundation
import Combine
import MapKit

@MainActor
class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(query: String) {
        guard query.count >= 2 else {
            suggestions = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func clear() {
        suggestions = []
        isSearching = false
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = Array(completer.results.prefix(5))
        Task { @MainActor in
            self.suggestions = results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }
}
