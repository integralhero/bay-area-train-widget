import WidgetKit
import CoreLocation
import Foundation

struct DepartureTimelineEntry: TimelineEntry {
    let date: Date
    let departures: [Departure]
    let stopName: String?
    let errorMessage: String?
}

struct DepartureTimelineProvider: TimelineProvider {
    private let widgetLocationManager = WidgetLocationManager()

    func placeholder(in context: Context) -> DepartureTimelineEntry {
        let entry = DepartureEntry.placeholder
        return DepartureTimelineEntry(
            date: entry.date,
            departures: entry.departures,
            stopName: entry.stopName,
            errorMessage: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DepartureTimelineEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            let result = await fetchDepartures()
            let now = Date()
            completion(DepartureTimelineEntry(
                date: now,
                departures: Array(result.departures.prefix(5)),
                stopName: result.stopName,
                errorMessage: result.departures.isEmpty ? result.errorMessage : nil
            ))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DepartureTimelineEntry>) -> Void) {
        Task {
            // Try to get a fresh location before fetching departures
            await refreshLocationIfNeeded()

            let result = await fetchDepartures()
            let now = Date()

            guard !result.departures.isEmpty else {
                // Back off when out of range or rate limited
                let backoff: TimeInterval
                if result.isRateLimited {
                    backoff = 10 * 60  // 10 min cooldown on 429
                } else if result.isOutOfRange {
                    backoff = 30 * 60  // 30 min when far away
                } else if result.isTimeout {
                    backoff = 3 * 60   // 3 min — likely transient network slowness
                } else {
                    backoff = 5 * 60   // 5 min normal retry
                }
                let nextUpdate = now.addingTimeInterval(backoff)
                let entry = DepartureTimelineEntry(
                    date: now, departures: [], stopName: result.stopName,
                    errorMessage: result.errorMessage
                )
                completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
                return
            }

            let departures = result.departures
            var entries: [DepartureTimelineEntry] = []

            // Cover until the last visible departure or 30 min, whichever is less
            let lastVisible = departures.prefix(5).last?.expectedArrival ?? now
            let endDate = min(
                max(lastVisible, now.addingTimeInterval(5 * 60)),
                now.addingTimeInterval(30 * 60)
            )

            // Generate per-minute entries so the gauge fills smoothly
            var entryDate = now
            while entryDate <= endDate {
                let active = departures.filter { $0.expectedArrival > entryDate }
                entries.append(DepartureTimelineEntry(
                    date: entryDate,
                    departures: Array(active.prefix(5)),
                    stopName: result.stopName,
                    errorMessage: active.isEmpty ? "No departures" : nil
                ))
                entryDate = entryDate.addingTimeInterval(60)
            }

            // Add entries shortly after each departure expires for quick rotation
            for departure in departures.prefix(5) {
                let expiryDate = departure.expectedArrival.addingTimeInterval(5)
                guard expiryDate > now, expiryDate < endDate else { continue }
                let active = departures.filter { $0.expectedArrival > expiryDate }
                entries.append(DepartureTimelineEntry(
                    date: expiryDate,
                    departures: Array(active.prefix(5)),
                    stopName: result.stopName,
                    errorMessage: active.isEmpty ? "No departures" : nil
                ))
            }

            entries.sort { $0.date < $1.date }
            let refreshDate = endDate.addingTimeInterval(10)
            completion(Timeline(entries: entries, policy: .after(refreshDate)))
        }
    }

    // MARK: - Location

    /// Request a fresh location from the widget extension's own CLLocationManager.
    /// Updates the cached location if successful, so fetchDepartures uses it.
    private func refreshLocationIfNeeded() async {
        // Only refresh if we have location permission
        let status = widgetLocationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }

        if let location = await widgetLocationManager.requestLocation() {
            UserDefaultsStore.setCachedLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
    }

    // MARK: - Data Fetching

    private struct FetchResult {
        let departures: [Departure]
        let stopName: String?
        let errorMessage: String?
        let isOutOfRange: Bool
        let isRateLimited: Bool
        var isTimeout: Bool = false
    }

    /// How long to stop hitting the API after a 429 response.
    private static let rateLimitCooldown: TimeInterval = 10 * 60

    /// Total deadline for a single timeline fetch. iOS gives widget tasks ~30s
    /// of wall-clock; anything beyond this leaves no time to build entries, so
    /// we bail out early and schedule a quick retry.
    private static let fetchBudget: TimeInterval = 20

    /// How long cached coordinates stay trustworthy without a refresh.
    private static let locationMaxAge: TimeInterval = 24 * 60 * 60

    private func fetchDepartures() async -> FetchResult {
        await withTaskGroup(of: FetchResult.self) { group in
            group.addTask { await self.performFetch() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(Self.fetchBudget * 1_000_000_000))
                return FetchResult(
                    departures: [], stopName: nil,
                    errorMessage: "Taking too long — try again",
                    isOutOfRange: false, isRateLimited: false,
                    isTimeout: true
                )
            }
            let first = await group.next() ?? FetchResult(
                departures: [], stopName: nil, errorMessage: nil,
                isOutOfRange: false, isRateLimited: false
            )
            group.cancelAll()
            return first
        }
    }

    private func performFetch() async -> FetchResult {
        guard let apiKey = UserDefaultsStore.apiKey, !apiKey.isEmpty else {
            return FetchResult(departures: [], stopName: nil,
                               errorMessage: "Open TrainWidget app to set API key",
                               isOutOfRange: false, isRateLimited: false)
        }

        guard let lat = UserDefaultsStore.cachedLatitude,
              let lon = UserDefaultsStore.cachedLongitude else {
            return FetchResult(departures: [], stopName: nil,
                               errorMessage: "Open app to set location",
                               isOutOfRange: false, isRateLimited: false)
        }

        // Guard against silently serving departures for a wildly outdated
        // location. If the timestamp is unset (older install) we let it pass;
        // once any refresh stamps it, the staleness check takes over.
        if let stamp = UserDefaultsStore.cachedLocationAt,
           Date().timeIntervalSince(stamp) > Self.locationMaxAge {
            return FetchResult(departures: [], stopName: nil,
                               errorMessage: "Open app to refresh location",
                               isOutOfRange: false, isRateLimited: false)
        }

        let agencies = UserDefaultsStore.enabledAgencies
        let cacheKey = DepartureCache.fingerprint(latitude: lat, longitude: lon, agencies: agencies)

        // A recently-fetched result from a sibling widget family is as good as
        // hitting the API again, and avoids pounding the quota.
        if let cached = DepartureCache.load(fingerprint: cacheKey) {
            return FetchResult(departures: cached.departures, stopName: cached.stopName,
                               errorMessage: nil, isOutOfRange: false, isRateLimited: false)
        }

        // Honor the shared rate-limit cooldown regardless of which widget is asking.
        if let last = UserDefaultsStore.lastRateLimitAt,
           Date().timeIntervalSince(last) < Self.rateLimitCooldown {
            return FetchResult(departures: [], stopName: nil,
                               errorMessage: "Slow down — try again soon",
                               isOutOfRange: false, isRateLimited: true)
        }

        // Refresh MUNI stops cache if stale — needed for both directions + bus stops
        let hasMuni = agencies.contains(.muniBus) || agencies.contains(.muniMetro)
        if hasMuni && StopData.cacheNeedsRefresh {
            await StopData.refreshMuniBusStops(apiKey: apiKey)
        }

        let stops = StopData.loadStops()

        var allDepartures: [Departure] = []
        var firstStopName: String?
        var hitRateLimit = false

        // When both MUNI Metro and Bus are enabled, find stops for each
        // type separately (they're at different locations), then query
        // each unique stop once parsing for both metro + bus lines
        let hasBothMuni = agencies.contains(.muniMetro) && agencies.contains(.muniBus)
        let effectiveAgencies: [TransitAgency] = hasBothMuni
            ? agencies.filter { $0 != .muniBus }
            : agencies

        for agency in effectiveAgencies {
            if hitRateLimit { break }

            var stopsToQuery: [TransitStop]

            if agency == .muniMetro && hasBothMuni {
                // Find metro stops and bus stops separately, then merge
                let metroStops = StopFinder.nearestStops(
                    latitude: lat, longitude: lon,
                    stops: stops, agencies: [.muniMetro],
                    maxDistance: StopFinder.maxRangeMeters
                )
                let busStops = StopFinder.nearestStops(
                    latitude: lat, longitude: lon,
                    stops: stops, agencies: [.muniBus], limit: 2,
                    maxDistance: StopFinder.maxRangeMeters
                )
                // Merge, deduplicate by ID
                var seenIds = Set<String>()
                var merged: [TransitStop] = []
                for stop in metroStops + busStops {
                    if seenIds.insert(stop.id).inserted {
                        merged.append(stop)
                    }
                }
                stopsToQuery = merged
            } else {
                stopsToQuery = StopFinder.nearestStops(
                    latitude: lat, longitude: lon,
                    stops: stops, agencies: [agency],
                    maxDistance: StopFinder.maxRangeMeters
                )
            }

            if let nearest = stopsToQuery.first, firstStopName == nil {
                firstStopName = nearest.name
            }

            let parseAgencies: [TransitAgency] = (agency == .muniMetro && hasBothMuni)
                ? [.muniMetro, .muniBus]
                : [agency]

            let countBefore = allDepartures.count
            for stop in stopsToQuery {
                // If the first stop already returned plenty of departures for
                // this agency, additional stops are usually redundant — skip
                // them to conserve quota. Threshold chosen so we still reach
                // the second stop if the first is sparse (e.g. one direction).
                //
                // Exception: stops effectively co-located with the user (within
                // 100m) are queried unconditionally. At places like Church &
                // Market the underground KLM platform and the surface J stop
                // sit within meters of each other but serve disjoint lines, so
                // a chatty first stop can't speak for the second.
                let distance = StopFinder.haversineDistance(
                    lat1: lat, lon1: lon, lat2: stop.latitude, lon2: stop.longitude
                )
                if distance > 100 && allDepartures.count - countBefore >= 4 { break }

                do {
                    let departures = try await TransitAPI.fetchDeparturesForStop(
                        apiKey: apiKey, stop: stop, asAgencies: parseAgencies
                    )
                    allDepartures.append(contentsOf: departures)
                } catch TransitAPIError.rateLimited {
                    hitRateLimit = true
                    break
                } catch {
                    continue
                }
            }
        }

        // Share the 429 signal across all widget families + the main app so
        // none of them retries until the cooldown elapses.
        if hitRateLimit {
            UserDefaultsStore.lastRateLimitAt = Date()
        }

        // If rate limited and we got nothing, show a specific message
        if hitRateLimit && allDepartures.isEmpty {
            return FetchResult(departures: [], stopName: firstStopName,
                               errorMessage: "Slow down — try again soon",
                               isOutOfRange: false, isRateLimited: true)
        }

        guard !allDepartures.isEmpty || firstStopName != nil else {
            return FetchResult(departures: [], stopName: nil,
                               errorMessage: "Not in the Bay Area",
                               isOutOfRange: true, isRateLimited: false)
        }

        allDepartures.sort { $0.expectedArrival < $1.expectedArrival }

        if allDepartures.isEmpty {
            return FetchResult(departures: [], stopName: firstStopName,
                               errorMessage: "No departures",
                               isOutOfRange: false, isRateLimited: false)
        }

        // A successful, non-rate-limited fetch clears the cooldown and seeds
        // the response cache for other widget families to reuse.
        if !hitRateLimit {
            UserDefaultsStore.lastRateLimitAt = nil
        }
        DepartureCache.save(departures: allDepartures, stopName: firstStopName, fingerprint: cacheKey)

        return FetchResult(departures: allDepartures, stopName: firstStopName,
                           errorMessage: nil, isOutOfRange: false, isRateLimited: false)
    }
}

// MARK: - Widget Location Manager

/// Lightweight location manager for the widget extension.
/// Requests a single location fix and returns it via async/await.
final class WidgetLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
