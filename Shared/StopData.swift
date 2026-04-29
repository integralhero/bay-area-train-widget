import Foundation

struct StopData {
    /// Loads bundled stops + any cached API stops (e.g., MUNI bus stops)
    static func loadStops() -> [TransitStop] {
        var stops = loadBundledStops()
        let cached = loadCachedStops()
        // Merge cached stops, avoiding duplicates by ID
        let existingIds = Set(stops.map(\.id))
        for stop in cached where !existingIds.contains(stop.id) {
            stops.append(stop)
        }
        return stops
    }

    /// Loads the bundled stops.json from the app bundle
    static func loadBundledStops() -> [TransitStop] {
        guard let url = Bundle.main.url(forResource: "stops", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([TransitStop].self, from: data)) ?? []
    }

    // MARK: - Cached API Stops

    private static let cacheKey = "cachedAPIStops"
    private static let cacheTimestampKey = "cachedAPIStopsTimestamp"
    /// Cache expires after 7 days
    private static let cacheMaxAge: TimeInterval = 7 * 24 * 60 * 60

    /// Loads cached stops from UserDefaults (shared app group)
    static func loadCachedStops() -> [TransitStop] {
        guard let data = UserDefaultsStore.defaults.data(forKey: cacheKey) else {
            return []
        }
        return (try? JSONDecoder().decode([TransitStop].self, from: data)) ?? []
    }

    /// Saves fetched stops to the cache
    static func cacheFetchedStops(_ stops: [TransitStop]) {
        guard let data = try? JSONEncoder().encode(stops) else { return }
        UserDefaultsStore.defaults.set(data, forKey: cacheKey)
        UserDefaultsStore.defaults.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
        UserDefaultsStore.defaults.set(cacheVersion, forKey: cacheVersionKey)
    }

    /// Cache version — bump to force re-fetch (e.g., after changing agency tagging)
    private static let cacheVersion = 2
    private static let cacheVersionKey = "cachedAPIStopsVersion"

    /// Whether the cache needs a refresh
    static var cacheNeedsRefresh: Bool {
        let version = UserDefaultsStore.defaults.integer(forKey: cacheVersionKey)
        if version < cacheVersion { return true }
        let timestamp = UserDefaultsStore.defaults.double(forKey: cacheTimestampKey)
        guard timestamp > 0 else { return true }
        return Date().timeIntervalSince1970 - timestamp > cacheMaxAge
    }

    /// Fetches all MUNI stops from the 511 API and caches them.
    /// Call this when the user enables MUNI Bus or when the cache is stale.
    static func refreshMuniBusStops(apiKey: String) async {
        guard let stops = try? await TransitAPI.fetchStops(apiKey: apiKey, agencyCode: "SF"),
              !stops.isEmpty else {
            return
        }
        cacheFetchedStops(stops)
    }
}

// MARK: - Departure Response Cache

/// Short-lived cache for a successful departure fetch. Lets sibling widget
/// families (rectangular lock + small/medium/large home) reuse one API call
/// when they refresh within a short window of each other.
struct DepartureCache {
    /// Short enough that live times stay current; long enough to coalesce
    /// back-to-back refreshes across widget families.
    static let ttl: TimeInterval = 30

    struct Entry: Codable {
        let departures: [Departure]
        let stopName: String?
        let timestamp: Date
        let fingerprint: String
    }

    private static let key = "cachedDepartureResponse"

    /// Returns a cached entry only if it matches the current inputs and is within TTL.
    static func load(fingerprint: String) -> Entry? {
        guard let data = UserDefaultsStore.defaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.fingerprint == fingerprint,
              Date().timeIntervalSince(entry.timestamp) < ttl else {
            return nil
        }
        return entry
    }

    static func save(departures: [Departure], stopName: String?, fingerprint: String) {
        let entry = Entry(departures: departures, stopName: stopName,
                          timestamp: Date(), fingerprint: fingerprint)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaultsStore.defaults.set(data, forKey: key)
    }

    /// Drop the cached response. Call when a setting that doesn't participate
    /// in the fingerprint (e.g. API key) changes, so the next fetch is live.
    static func clear() {
        UserDefaultsStore.defaults.removeObject(forKey: key)
    }

    /// A stable key for the set of inputs that determine which stops + agencies
    /// get queried. Location rounded to ~100m so minor drift doesn't miss the cache.
    static func fingerprint(latitude: Double, longitude: Double, agencies: [TransitAgency]) -> String {
        let lat = String(format: "%.3f", latitude)
        let lon = String(format: "%.3f", longitude)
        let ag = agencies.map(\.rawValue).sorted().joined(separator: ",")
        return "\(lat),\(lon)|\(ag)"
    }
}
