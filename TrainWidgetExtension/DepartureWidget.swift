import SwiftUI
import WidgetKit

struct DepartureWidget: Widget {
    let kind = "DepartureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DepartureTimelineProvider()) { entry in
            DepartureWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Departure")
        .description("Shows upcoming transit departures near you.")
        .supportedFamilies([
            .accessoryRectangular, .accessoryInline, .accessoryCircular,
            .systemSmall, .systemMedium, .systemLarge,
        ])
    }
}

struct DepartureWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DepartureTimelineEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            rectangularView
        }
    }

    // MARK: - Lock Screen Filtering

    /// Lock screen widgets filter to starred lines (when any are set) because
    /// real estate is limited. Home screen widgets keep showing variety.
    ///
    /// Filtering is per-agency: if you've starred lines belonging to agency X,
    /// only those starred lines from X are shown — but agencies with no starred
    /// lines pass through unfiltered. Without this, starring a MUNI Bus route
    /// would silently drop every MUNI Metro and BART departure.
    private var lockScreenDepartures: [Departure] {
        let starred = Set(UserDefaultsStore.starredLines)
        guard !starred.isEmpty else { return entry.departures }
        return entry.departures.filter { departure in
            let agencyHasStar = departure.agency.knownLines.contains(where: starred.contains)
            return !agencyHasStar || starred.contains(departure.lineName)
        }
    }

    /// Pick up to `count` departures, preferring unique destinations first so
    /// that both directions of a line can appear when available.
    private func preferBothDirections(_ departures: [Departure], count: Int) -> [Departure] {
        var picked: [Departure] = []
        var seenDestinations: Set<String> = []
        for d in departures {
            if picked.count >= count { break }
            if !seenDestinations.contains(d.destination) {
                picked.append(d)
                seenDestinations.insert(d.destination)
            }
        }
        if picked.count < count {
            for d in departures {
                if picked.count >= count { break }
                if !picked.contains(where: { $0.id == d.id }) {
                    picked.append(d)
                }
            }
        }
        return picked
    }

    // MARK: - Rectangular (main lock screen widget)

    private var rectangularView: some View {
        let displayed = preferBothDirections(lockScreenDepartures, count: 2)
        return VStack(alignment: .leading, spacing: 2) {
            if let stopName = entry.stopName {
                Label(stopName, systemImage: "mappin.circle.fill")
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if displayed.isEmpty {
                    Spacer()
                    if let error = entry.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No upcoming departures")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(displayed) { departure in
                        HStack(spacing: 4) {
                            Text(departure.lineName)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.heavy)
                                .frame(minWidth: 16)
                            if departure.agency != .bart {
                                Text(departure.destination)
                                    .font(.caption2)
                                    .fontWeight(.light)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                            Text(timerInterval: entry.date...departure.expectedArrival, countsDown: true)
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }
            } else if let error = entry.errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: error.contains("Slow") ? "clock" : "location.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "tram.fill")
                    .font(.title3)
                Text("Open app to configure")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Inline (single line above time)

    private var inlineView: some View {
        Group {
            if let departure = lockScreenDepartures.first {
                Text("\(Image(systemName: "tram.fill")) \(departure.lineName) \(departure.destination) \(departure.minutesAway)m")
            } else if let error = entry.errorMessage {
                Text(error)
            } else {
                Text("No departures")
            }
        }
    }

    // MARK: - Circular (gauge widget)

    private var circularView: some View {
        Group {
            if let departure = lockScreenDepartures.first,
               departure.expectedArrival > entry.date {
                let window: TimeInterval = 15 * 60
                let remaining = departure.expectedArrival.timeIntervalSince(entry.date)
                let progress = 1.0 - min(remaining / window, 1.0)
                Gauge(value: progress) {
                    Text(departure.lineName)
                } currentValueLabel: {
                    VStack(spacing: 0) {
                        Text(departure.lineName)
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                        Text("\(Int(remaining / 60))m")
                            .font(.system(.caption2, design: .rounded))
                            .monospacedDigit()
                    }
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 2) {
                        Image(systemName: "tram.fill")
                            .font(.caption)
                        if entry.errorMessage != nil {
                            Text("—")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    DepartureWidget()
} timeline: {
    DepartureTimelineEntry(
        date: .now,
        departures: [
            Departure(lineName: "N", destination: "Ocean Beach", expectedArrival: Date().addingTimeInterval(180), stopName: "Church & Duboce", agency: .muniMetro),
            Departure(lineName: "J", destination: "Balboa Park", expectedArrival: Date().addingTimeInterval(420), stopName: "Church & Duboce", agency: .muniMetro),
        ],
        stopName: "Church & Duboce",
        errorMessage: nil
    )
}

#Preview("Inline", as: .accessoryInline) {
    DepartureWidget()
} timeline: {
    DepartureTimelineEntry(
        date: .now,
        departures: [
            Departure(lineName: "N", destination: "Ocean Beach", expectedArrival: Date().addingTimeInterval(180), stopName: "Church & Duboce", agency: .muniMetro),
        ],
        stopName: "Church & Duboce",
        errorMessage: nil
    )
}

#Preview("Circular", as: .accessoryCircular) {
    DepartureWidget()
} timeline: {
    DepartureTimelineEntry(
        date: .now,
        departures: [
            Departure(lineName: "N", destination: "Ocean Beach", expectedArrival: Date().addingTimeInterval(180), stopName: "Church & Duboce", agency: .muniMetro),
        ],
        stopName: "Church & Duboce",
        errorMessage: nil
    )
}

#Preview("Small", as: .systemSmall) {
    DepartureWidget()
} timeline: {
    DepartureTimelineEntry(
        date: .now,
        departures: [
            Departure(lineName: "N", destination: "Ocean Beach", expectedArrival: Date().addingTimeInterval(180), stopName: "Church & Duboce", agency: .muniMetro),
            Departure(lineName: "J", destination: "Balboa Park", expectedArrival: Date().addingTimeInterval(420), stopName: "Church & Duboce", agency: .muniMetro),
        ],
        stopName: "Church & Duboce",
        errorMessage: nil
    )
}

#Preview("Medium", as: .systemMedium) {
    DepartureWidget()
} timeline: {
    DepartureTimelineEntry(
        date: .now,
        departures: [
            Departure(lineName: "N", destination: "Ocean Beach", expectedArrival: Date().addingTimeInterval(180), stopName: "Church & Duboce", agency: .muniMetro),
            Departure(lineName: "J", destination: "Balboa Park", expectedArrival: Date().addingTimeInterval(420), stopName: "Church & Duboce", agency: .muniMetro),
            Departure(lineName: "T", destination: "Sunnydale", expectedArrival: Date().addingTimeInterval(720), stopName: "Church & Duboce", agency: .muniMetro),
        ],
        stopName: "Church & Duboce",
        errorMessage: nil
    )
}

#Preview("Large", as: .systemLarge) {
    DepartureWidget()
} timeline: {
    DepartureTimelineEntry(
        date: .now,
        departures: [
            Departure(lineName: "N", destination: "Ocean Beach", expectedArrival: Date().addingTimeInterval(120), stopName: "Church & Duboce", agency: .muniMetro),
            Departure(lineName: "J", destination: "Balboa Park", expectedArrival: Date().addingTimeInterval(300), stopName: "Church & Duboce", agency: .muniMetro),
            Departure(lineName: "N", destination: "Caltrain", expectedArrival: Date().addingTimeInterval(540), stopName: "Church & Duboce", agency: .muniMetro),
            Departure(lineName: "T", destination: "Sunnydale", expectedArrival: Date().addingTimeInterval(720), stopName: "Church & Duboce", agency: .muniMetro),
            Departure(lineName: "J", destination: "Embarcadero", expectedArrival: Date().addingTimeInterval(900), stopName: "Church & Duboce", agency: .muniMetro),
        ],
        stopName: "Church & Duboce",
        errorMessage: nil
    )
}
