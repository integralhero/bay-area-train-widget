import Foundation

enum TransitAPIError: Error, LocalizedError {
    case rateLimited
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .rateLimited: return "Rate limited — try again shortly"
        case .serverError(let code): return "Server error (\(code))"
        }
    }
}

struct TransitAPI {
    /// Fetches departures for a stop, including both directions if altId is available.
    static func fetchDeparturesForStop(apiKey: String, stop: TransitStop, asAgency: TransitAgency? = nil) async throws -> [Departure] {
        let agency = asAgency ?? stop.agency
        var all = try await fetchDepartures(apiKey: apiKey, agency: agency, stopCode: stop.id)
        if let altId = stop.altId {
            // Don't lose primary results if the alt direction fails
            if let altDepartures = try? await fetchDepartures(apiKey: apiKey, agency: agency, stopCode: altId) {
                all.append(contentsOf: altDepartures)
            }
        }
        all.sort { $0.expectedArrival < $1.expectedArrival }
        return all
    }

    /// Fetches departures for a stop, parsing for multiple agencies from a single API call.
    /// Use when both muniMetro and muniBus are enabled to avoid duplicate requests.
    static func fetchDeparturesForStop(apiKey: String, stop: TransitStop, asAgencies: [TransitAgency]) async throws -> [Departure] {
        guard let firstAgency = asAgencies.first else { return [] }
        // One API call — the raw data is the same regardless of agency filter
        let rawData = try await fetchRawStopData(apiKey: apiKey, agencyCode: firstAgency.apiAgencyCode, stopCode: stop.id)
        var all: [Departure] = []
        for agency in asAgencies {
            all.append(contentsOf: try parseSIRIResponse(rawData, agency: agency))
        }
        if let altId = stop.altId {
            if let altData = try? await fetchRawStopData(apiKey: apiKey, agencyCode: firstAgency.apiAgencyCode, stopCode: altId) {
                for agency in asAgencies {
                    all.append(contentsOf: (try? parseSIRIResponse(altData, agency: agency)) ?? [])
                }
            }
        }
        all.sort { $0.expectedArrival < $1.expectedArrival }
        return all
    }

    /// Per-request network timeout. Short enough that a single stalled call
    /// can't eat the widget's entire runtime.
    private static let requestTimeout: TimeInterval = 8

    /// Issues a GET with a bounded timeout and one automatic retry for
    /// transient failures (5xx, dropped connection). Strips the UTF-8 BOM
    /// that 511.org sometimes includes so callers get ready-to-parse JSON.
    /// Rate-limits (429) are never retried — the caller marks the shared
    /// cooldown so siblings don't dogpile.
    private static func performRequest(url: URL, timeout: TimeInterval = requestTimeout) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        var lastError: Error?
        for attempt in 0..<2 {
            if attempt > 0 {
                // Jittered backoff so parallel retries don't synchronize.
                let jitter = Double.random(in: 0.3...0.7)
                try? await Task.sleep(nanoseconds: UInt64(jitter * 1_000_000_000))
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 429 { throw TransitAPIError.rateLimited }
                    if (500..<600).contains(http.statusCode) {
                        lastError = TransitAPIError.serverError(http.statusCode)
                        if attempt == 0 { continue }
                        throw lastError!
                    }
                    if http.statusCode != 200 {
                        throw TransitAPIError.serverError(http.statusCode)
                    }
                }
                if data.starts(with: [0xEF, 0xBB, 0xBF]) { return data.dropFirst(3) }
                return data
            } catch TransitAPIError.rateLimited {
                throw TransitAPIError.rateLimited
            } catch let error as URLError where error.code == .networkConnectionLost {
                lastError = error
                if attempt == 0 { continue }
                throw error
            }
        }
        throw lastError ?? TransitAPIError.serverError(0)
    }

    /// Fetches raw SIRI data for a stop code, handling BOM and error codes.
    private static func fetchRawStopData(apiKey: String, agencyCode: String, stopCode: String) async throws -> Data {
        var components = URLComponents(string: "https://api.511.org/transit/StopMonitoring")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "agency", value: agencyCode),
            URLQueryItem(name: "stopCode", value: stopCode),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else { return Data() }
        return try await performRequest(url: url)
    }

    /// Fetches upcoming departures for a single stop code from the 511.org StopMonitoring API.
    static func fetchDepartures(apiKey: String, agency: TransitAgency, stopCode: String) async throws -> [Departure] {
        var components = URLComponents(string: "https://api.511.org/transit/StopMonitoring")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "agency", value: agency.apiAgencyCode),
            URLQueryItem(name: "stopCode", value: stopCode),
            URLQueryItem(name: "format", value: "json"),
        ]

        guard let url = components.url else { return [] }
        let cleanedData = try await performRequest(url: url)
        return try parseSIRIResponse(cleanedData, agency: agency)
    }

    /// Extracts a string from a SIRI field that may be a plain String, a single-element Array, or nil.
    private static func siriString(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let arr = value as? [String], let first = arr.first { return first }
        return ""
    }

    private static func parseSIRIResponse(_ data: Data, agency: TransitAgency) throws -> [Departure] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let serviceDelivery = json["ServiceDelivery"] as? [String: Any] else {
            return []
        }

        // StopMonitoringDelivery can be a dict or a single-element array
        let smd: [String: Any]
        if let dict = serviceDelivery["StopMonitoringDelivery"] as? [String: Any] {
            smd = dict
        } else if let arr = serviceDelivery["StopMonitoringDelivery"] as? [[String: Any]], let first = arr.first {
            smd = first
        } else {
            return []
        }

        guard let monitoredStopVisits = smd["MonitoredStopVisit"] as? [[String: Any]] else {
            return []
        }

        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let iso8601NoFrac = ISO8601DateFormatter()
        iso8601NoFrac.formatOptions = [.withInternetDateTime]

        var departures: [Departure] = []

        for visit in monitoredStopVisits {
            guard let journey = visit["MonitoredVehicleJourney"] as? [String: Any],
                  let call = journey["MonitoredCall"] as? [String: Any] else {
                continue
            }

            let lineName = siriString(journey["PublishedLineName"])
            let lineRef = siriString(journey["LineRef"])
            let destination = siriString(journey["DestinationName"])
            let stopName = siriString(call["StopPointName"])

            // Try ExpectedDepartureTime, then ExpectedArrivalTime, then AimedDepartureTime
            let timeString = siriString(call["ExpectedDepartureTime"])
                .ifEmpty(siriString(call["ExpectedArrivalTime"]))
                .ifEmpty(siriString(call["AimedDepartureTime"]))
                .ifEmpty(siriString(call["AimedArrivalTime"]))

            guard !timeString.isEmpty,
                  let arrivalDate = iso8601.date(from: timeString) ?? iso8601NoFrac.date(from: timeString) else {
                continue
            }

            // Only include future departures
            guard arrivalDate > Date() else { continue }

            // For MUNI Metro, only include metro/tram lines
            if agency == .muniMetro {
                guard let shortName = muniMetroName(lineName) else { continue }
                departures.append(Departure(
                    lineName: shortName,
                    destination: cleanMuniDest(destination),
                    expectedArrival: arrivalDate,
                    stopName: stopName,
                    agency: agency
                ))
                continue
            }

            // For MUNI Bus, include everything that ISN'T a metro line
            if agency == .muniBus {
                if muniMetroName(lineName) != nil { continue }  // skip metro lines
                // Use LineRef (route number like "24") instead of PublishedLineName ("DIVISADERO")
                let busDisplayName = lineRef.isEmpty ? lineName : lineRef
                departures.append(Departure(
                    lineName: busDisplayName,
                    destination: cleanMuniDest(destination),
                    expectedArrival: arrivalDate,
                    stopName: stopName,
                    agency: agency
                ))
                continue
            }

            // For BART, use abbreviated destination as lineName since
            // PublishedLineName is a long route description
            let displayLine = agency == .bart ? bartShortDest(destination) : lineName
            departures.append(Departure(
                lineName: displayLine,
                destination: destination,
                expectedArrival: arrivalDate,
                stopName: stopName,
                agency: agency
            ))
        }

        return departures.sorted { $0.expectedArrival < $1.expectedArrival }
    }
}

private let muniMetroMap: [String: String] = [
    "CHURCH": "J",
    "INGLESIDE": "K",
    "TARAVAL": "L",
    "OCEAN VIEW": "M",
    "OCEANVIEW": "M",
    "JUDAH": "N",
    "THIRD": "T",
    "THIRD STREET": "T",
    "3RD STREET": "T",
    "SHUTTLE": "S",
    "F MARKET & WHARVES": "F",
    "F-MARKET": "F",
    "F": "F",
    "J": "J", "K": "K", "L": "L", "M": "M", "N": "N", "T": "T", "S": "S",
]

private func muniMetroName(_ raw: String) -> String? {
    return muniMetroMap[raw.uppercased()]
}

private let muniDestOverrides: [String: String] = [
    "Balboa Park BART/Mezzanine Level": "Balboa Park",
    "Metro Embarcadero Station": "Embarcadero",
    "Metro Montgomery Station": "Montgomery",
    "Metro Powell Station": "Powell",
    "Metro Civic Center Station": "Civic Center",
    "Metro Church Station": "Church",
    "Metro Van Ness Station": "Van Ness",
    "Metro Forest Hill Station": "Forest Hill",
    "Metro Castro Station": "Castro",
    "Metro West Portal Station": "West Portal",
    "Caltrain/King & 4th": "Caltrain",
    "SF Zoo": "Zoo",
]

private func cleanMuniDest(_ dest: String) -> String {
    if let override = muniDestOverrides[dest] { return override }
    var s = dest
    for suffix in [" BART/Mezzanine Level", " BART Station", " BART", " Station", " Transit Center"] {
        if s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)) }
    }
    if s.hasPrefix("Metro ") { s = String(s.dropFirst(6)) }
    // Shorten street suffixes for bus destinations: "3rd St & Palou Ave" → "3rd & Palou"
    s = s.replacingOccurrences(of: " Street", with: " St")
    s = s.replacingOccurrences(of: " Avenue", with: " Ave")
    s = s.replacingOccurrences(of: " Boulevard", with: " Blvd")
    // Drop trailing " St", " Ave", " Blvd" from the last part
    for suffix in [" St", " Ave", " Blvd", " Rd", " Dr", " Way", " Pl"] {
        if s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)) }
    }
    // Drop " St" before " & " to shorten cross streets: "3rd St & Palou" → "3rd & Palou"
    s = s.replacingOccurrences(of: " St & ", with: " & ")
    s = s.replacingOccurrences(of: " Ave & ", with: " & ")
    return s
}

private let bartDestAbbrev: [String: String] = [
    "San Francisco International Airport": "SFO",
    "Millbrae (Caltrain Transfer Platform)": "Millbrae",
    "Berryessa / North San Jose": "Berryessa",
    "Dublin / Pleasanton": "Dublin",
    "Pittsburg / Bay Point": "Pittsburg",
    "Pleasant Hill / Contra Costa Centre": "Pleasant Hl",
    "North Concord / Martinez": "N Concord",
    "12th Street / Oakland City Center": "12th St Oak",
    "Civic Center / UN Plaza": "Civic Ctr",
    "16th Street / Mission": "16th St",
    "24th Street / Mission": "24th St",
    "Downtown Berkeley": "Dwntn Berk",
    "El Cerrito Del Norte": "El Cerr DN",
    "El Cerrito Plaza": "El Cerr Plz",
    "West Dublin / Pleasanton": "W Dublin",
    "South San Francisco": "S San Fran",
    "Warm Springs / South Fremont": "Warm Spgs",
    "Oakland International Airport Station": "OAK Airport",
]

private func bartShortDest(_ dest: String) -> String {
    return bartDestAbbrev[dest] ?? dest
}

extension TransitAPI {
    /// Fetches all stops for an agency from the 511.org stops endpoint.
    static func fetchStops(apiKey: String, agencyCode: String) async throws -> [TransitStop] {
        var components = URLComponents(string: "https://api.511.org/transit/stops")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "operator_id", value: agencyCode),
            URLQueryItem(name: "format", value: "json"),
        ]

        guard let url = components.url else { return [] }

        // Stops dataset is much bigger than a single StopMonitoring response,
        // so give it a longer per-request budget.
        let cleanedData: Data
        do {
            cleanedData = try await performRequest(url: url, timeout: 15)
        } catch {
            return []
        }

        guard let json = try? JSONSerialization.jsonObject(with: cleanedData) as? [String: Any],
              let contents = json["Contents"] as? [String: Any],
              let dataObjects = contents["dataObjects"] as? [String: Any],
              let scheduledStopPoints = dataObjects["ScheduledStopPoint"] as? [[String: Any]] else {
            return []
        }

        var stops: [TransitStop] = []
        for point in scheduledStopPoints {
            guard let id = point["id"] as? String,
                  let name = point["Name"] as? String,
                  let location = point["Location"] as? [String: Any],
                  let lat = location["Latitude"] as? String,
                  let lon = location["Longitude"] as? String,
                  let latitude = Double(lat),
                  let longitude = Double(lon) else {
                continue
            }

            // Skip stops without valid coordinates
            guard latitude != 0 && longitude != 0 else { continue }

            stops.append(TransitStop(
                id: id, name: name,
                latitude: latitude, longitude: longitude,
                agency: .muniBus, // Tag as muniBus so they don't pollute muniMetro stop selection
                altId: nil
            ))
        }

        return stops
    }

    /// Debug: fetches raw info about what the API returns for a stop code, without filtering.
    static func debugFetch(apiKey: String, agency: TransitAgency, stopCode: String) async throws -> String {
        var components = URLComponents(string: "https://api.511.org/transit/StopMonitoring")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "agency", value: agency.apiAgencyCode),
            URLQueryItem(name: "stopCode", value: stopCode),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else { return "Bad URL" }
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0

        let cleanedData: Data
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            cleanedData = data.dropFirst(3)
        } else {
            cleanedData = data
        }

        guard let json = try? JSONSerialization.jsonObject(with: cleanedData) as? [String: Any],
              let sd = json["ServiceDelivery"] as? [String: Any] else {
            let raw = String(data: cleanedData.prefix(300), encoding: .utf8) ?? "no data"
            return "HTTP \(httpStatus). Raw: \(raw)"
        }

        let smd: [String: Any]?
        if let dict = sd["StopMonitoringDelivery"] as? [String: Any] {
            smd = dict
        } else if let arr = sd["StopMonitoringDelivery"] as? [[String: Any]], let first = arr.first {
            smd = first
        } else {
            smd = nil
        }

        guard let smd, let visits = smd["MonitoredStopVisit"] as? [[String: Any]] else {
            return "HTTP \(httpStatus). No MonitoredStopVisit. Keys: \(smd?.keys.sorted() ?? [])"
        }

        var lines: [String] = []
        for visit in visits.prefix(5) {
            if let j = visit["MonitoredVehicleJourney"] as? [String: Any] {
                let ln = siriString(j["PublishedLineName"])
                let dest = siriString(j["DestinationName"])
                let call = j["MonitoredCall"] as? [String: Any]
                let time = siriString(call?["ExpectedDepartureTime"])
                    .ifEmpty(siriString(call?["ExpectedArrivalTime"]))
                    .ifEmpty(siriString(call?["AimedDepartureTime"]))
                lines.append("\(ln)→\(dest) @\(time.suffix(14))")
            }
        }
        return "HTTP \(httpStatus). \(visits.count) visits. \(lines.joined(separator: "; "))"
    }
}

private extension String {
    func ifEmpty(_ other: String) -> String {
        isEmpty ? other : self
    }
}
