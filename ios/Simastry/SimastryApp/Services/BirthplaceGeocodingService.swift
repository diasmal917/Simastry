import Foundation
import CoreLocation

nonisolated struct ResolvedBirthplace: Sendable {
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
}

nonisolated final class BirthplaceGeocodingService {
    func resolve(_ place: String) async -> ResolvedBirthplace? {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(place)
            guard let placemark = placemarks.first,
                  let coordinate = placemark.location?.coordinate,
                  let timeZone = placemark.timeZone else {
                return nil
            }

            return ResolvedBirthplace(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timeZone: timeZone
            )
        } catch {
            return nil
        }
    }
}
