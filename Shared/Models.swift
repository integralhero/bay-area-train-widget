import Foundation

enum TransitAgency: String, Codable, CaseIterable, Identifiable {
    case muniMetro = "SF"
    case muniBus = "SF_BUS"
    case bart = "BA"
    case acTransit = "AC"

    var id: String { rawValue }

    /// The 511 API agency code (both MUNI types use "SF")
    var apiAgencyCode: String {
        switch self {
        case .muniMetro, .muniBus: return "SF"
        case .bart: return "BA"
        case .acTransit: return "AC"
        }
    }

    var displayName: String {
        switch self {
        case .muniMetro: return "MUNI Metro"
        case .muniBus: return "MUNI Bus"
        case .bart: return "BART"
        case .acTransit: return "AC Transit"
        }
    }

    var sfSymbol: String {
        switch self {
        case .muniMetro: return "tram.fill"
        case .muniBus: return "bus.fill"
        case .bart: return "train.side.front.car"
        case .acTransit: return "bus.doubledecker"
        }
    }

    var knownLines: [String] {
        switch self {
        case .muniMetro: return ["F", "J", "K", "L", "M", "N", "T", "S"]
        case .muniBus: return [
            "1", "2", "5", "5R", "6", "7", "8", "9", "9R",
            "12", "14", "14R", "18", "19", "21", "22", "23", "24", "25",
            "27", "28", "28R", "29", "30", "31", "33", "35", "36", "37",
            "38", "38R", "39", "43", "44", "45", "47", "48", "49",
            "52", "54", "55", "56", "57", "66", "67",
        ]
        case .bart: return ["SFO", "Millbrae", "Berryessa", "Dublin", "Richmond",
                            "Daly City", "Antioch", "Pittsburg/Bay Point"]
        case .acTransit: return []
        }
    }

    var subtitle: String {
        switch self {
        case .muniMetro: return "Light rail"
        case .muniBus: return "SF bus lines"
        case .bart: return "Bay Area Rapid Transit"
        case .acTransit: return "East Bay bus"
        }
    }
}

struct TransitStop: Codable, Identifiable {
    let id: String          // stop code used in API
    let name: String
    let latitude: Double
    let longitude: Double
    let agency: TransitAgency
    let altId: String?      // second directional stop code (BART)

    init(id: String, name: String, latitude: Double, longitude: Double, agency: TransitAgency, altId: String?) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.agency = agency
        self.altId = altId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        agency = try c.decode(TransitAgency.self, forKey: .agency)
        altId = try c.decodeIfPresent(String.self, forKey: .altId)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, agency, altId
    }
}

struct Departure: Codable, Identifiable {
    let id = UUID()
    let lineName: String        // e.g. "N", "Red", "51B"
    let destination: String     // e.g. "Ocean Beach"
    let expectedArrival: Date
    let stopName: String
    let agency: TransitAgency

    var minutesAway: Int {
        max(0, Int(expectedArrival.timeIntervalSinceNow / 60))
    }

    // id is synthesized fresh on decode — only the underlying fields are persisted
    private enum CodingKeys: String, CodingKey {
        case lineName, destination, expectedArrival, stopName, agency
    }
}

struct DepartureEntry {
    let date: Date
    let departures: [Departure]
    let stopName: String?
    let errorMessage: String?

    static var placeholder: DepartureEntry {
        DepartureEntry(
            date: .now,
            departures: [
                Departure(lineName: "N", destination: "Ocean Beach", expectedArrival: Date().addingTimeInterval(180), stopName: "Church & Duboce", agency: .muniMetro),
                Departure(lineName: "J", destination: "Balboa Park", expectedArrival: Date().addingTimeInterval(420), stopName: "Church & Duboce", agency: .muniMetro),
            ],
            stopName: "Church & Duboce",
            errorMessage: nil
        )
    }

    static var empty: DepartureEntry {
        DepartureEntry(date: .now, departures: [], stopName: nil, errorMessage: nil)
    }
}
