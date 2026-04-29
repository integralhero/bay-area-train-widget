import Foundation

struct StopFinder {
    /// Maximum distance in meters to consider a stop "nearby" (~50 miles)
    static let maxRangeMeters: Double = 80_000

    /// Returns the nearest stops from the given list, filtered by enabled agencies.
    /// If maxDistance is set, stops further than that are excluded.
    static func nearestStops(
        latitude: Double,
        longitude: Double,
        stops: [TransitStop],
        agencies: [TransitAgency],
        limit: Int = 2,
        maxDistance: Double? = nil
    ) -> [TransitStop] {
        let agencySet = Set(agencies)
        // MUNI Bus uses the same physical stops as MUNI Metro
        let expandedSet = agencySet.contains(.muniBus)
            ? agencySet.union([.muniMetro])
            : agencySet
        let sorted = stops
            .filter { expandedSet.contains($0.agency) }
            .sorted { a, b in
                haversineDistance(lat1: latitude, lon1: longitude, lat2: a.latitude, lon2: a.longitude) <
                haversineDistance(lat1: latitude, lon1: longitude, lat2: b.latitude, lon2: b.longitude)
            }
        if let maxDistance {
            return sorted
                .filter { haversineDistance(lat1: latitude, lon1: longitude, lat2: $0.latitude, lon2: $0.longitude) <= maxDistance }
                .prefix(limit)
                .map { $0 }
        }
        return sorted.prefix(limit).map { $0 }
    }

    /// Haversine distance in meters between two coordinates.
    static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
