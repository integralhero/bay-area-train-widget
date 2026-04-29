import Foundation

struct UserDefaultsStore {
    static let defaults: UserDefaults = {
        UserDefaults(suiteName: "group.com.trainwidget.app") ?? .standard
    }()

    // MARK: - API Key

    static var apiKey: String? {
        get { defaults.string(forKey: "apiKey") }
        set {
            defaults.set(newValue, forKey: "apiKey")

        }
    }

    // MARK: - Enabled Agencies

    static var enabledAgencies: [TransitAgency] {
        get {
            guard let raw = defaults.stringArray(forKey: "enabledAgencies") else {
                return TransitAgency.allCases
            }
            return raw.compactMap { TransitAgency(rawValue: $0) }
        }
        set {
            defaults.set(newValue.map(\.rawValue), forKey: "enabledAgencies")

        }
    }

    // MARK: - Starred Lines

    static var starredLines: [String] {
        get { defaults.stringArray(forKey: "starredLines") ?? [] }
        set {
            defaults.set(newValue, forKey: "starredLines")

        }
    }

    // MARK: - Cached Location

    static var cachedLatitude: Double? {
        get {
            defaults.object(forKey: "cachedLatitude") as? Double
        }
        set {
            defaults.set(newValue, forKey: "cachedLatitude")

        }
    }

    static var cachedLongitude: Double? {
        get {
            defaults.object(forKey: "cachedLongitude") as? Double
        }
        set {
            defaults.set(newValue, forKey: "cachedLongitude")

        }
    }

    static var hasLocation: Bool {
        cachedLatitude != nil && cachedLongitude != nil
    }

    /// When the cached location was last updated. Used to flag stale cached
    /// coordinates (e.g. user revoked location permission and hasn't opened
    /// the app in a long time) instead of silently showing the wrong stop.
    static var cachedLocationAt: Date? {
        get {
            let t = defaults.double(forKey: "cachedLocationAt")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let date = newValue {
                defaults.set(date.timeIntervalSince1970, forKey: "cachedLocationAt")
            } else {
                defaults.removeObject(forKey: "cachedLocationAt")
            }
        }
    }

    /// Atomically update the cached location and its timestamp.
    static func setCachedLocation(latitude: Double, longitude: Double) {
        cachedLatitude = latitude
        cachedLongitude = longitude
        cachedLocationAt = Date()
    }

    // MARK: - Rate Limit Cooldown

    /// Timestamp of the most recent 429 from the 511 API. Shared across all
    /// widget families + the main app so nobody retries during the cooldown.
    static var lastRateLimitAt: Date? {
        get {
            let t = defaults.double(forKey: "lastRateLimitAt")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let date = newValue {
                defaults.set(date.timeIntervalSince1970, forKey: "lastRateLimitAt")
            } else {
                defaults.removeObject(forKey: "lastRateLimitAt")
            }
        }
    }

    // MARK: - Migration

    static func migrateIfNeeded() {
        let migrationKey = "v2_agency_migration_done"
        guard !defaults.bool(forKey: migrationKey) else { return }

        if let raw = defaults.stringArray(forKey: "enabledAgencies") {
            var migrated = raw.map { $0 == "SF" ? TransitAgency.muniMetro.rawValue : $0 }
            if raw.contains("SF") && !migrated.contains(TransitAgency.muniBus.rawValue) {
                migrated.append(TransitAgency.muniBus.rawValue)
            }
            defaults.set(migrated, forKey: "enabledAgencies")
        }

        defaults.set(true, forKey: migrationKey)
        defaults.synchronize()
    }
}
