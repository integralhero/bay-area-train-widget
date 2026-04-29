import SwiftUI
import WidgetKit

// MARK: - Colors (inline since widget extension can't access main app's asset catalog)

private enum WidgetTheme {
    static let background = Color(light: .init(red: 0.941, green: 0.922, blue: 0.878),
                                   dark: .init(red: 0.086, green: 0.102, blue: 0.078))
    static let surface = Color(light: .init(red: 0.894, green: 0.867, blue: 0.816),
                                dark: .init(red: 0.133, green: 0.157, blue: 0.125))
    static let textPrimary = Color(light: .init(red: 0.118, green: 0.165, blue: 0.118),
                                    dark: .init(red: 0.894, green: 0.867, blue: 0.816))
    static let muted = Color(light: .init(red: 0.478, green: 0.459, blue: 0.408),
                              dark: .init(red: 0.420, green: 0.459, blue: 0.396))
    static let primary = Color(light: .init(red: 0.176, green: 0.373, blue: 0.176),
                                dark: .init(red: 0.290, green: 0.561, blue: 0.290))
    static let secondary = Color(light: .init(red: 0.769, green: 0.267, blue: 0.102),
                                  dark: .init(red: 0.910, green: 0.380, blue: 0.165))
    static let border = Color(light: .init(red: 0.831, green: 0.800, blue: 0.737),
                               dark: .init(red: 0.200, green: 0.239, blue: 0.188))
}

private extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Departure Row (shared by medium + large)

private struct DepartureRow: View {
    let departure: Departure
    let entryDate: Date
    let isNext: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: departure.agency.sfSymbol)
                .font(.system(size: 10))
                .foregroundStyle(WidgetTheme.muted)
                .frame(width: 14)

            Text(departure.lineName)
                .font(.system(size: 14, design: .monospaced))
                .fontWeight(.heavy)
                .foregroundStyle(isNext ? WidgetTheme.secondary : WidgetTheme.primary)
                .frame(width: 28, alignment: .leading)
                .lineLimit(1)

            Text(departure.destination)
                .font(.system(size: 13))
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            if departure.expectedArrival > entryDate {
                Text(timerInterval: entryDate...departure.expectedArrival, countsDown: true)
                    .font(.system(size: 14, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(isNext ? WidgetTheme.secondary : WidgetTheme.textPrimary)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Stop Header

private struct StopHeader: View {
    let stopName: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 10))
            Text(stopName)
                .font(.system(size: 11, design: .monospaced))
                .tracking(0.5)
        }
        .foregroundStyle(WidgetTheme.muted)
        .lineLimit(1)
    }
}

// MARK: - Empty State

private struct WidgetEmptyState: View {
    let errorMessage: String?
    let stopName: String?

    private var iconName: String {
        guard let msg = errorMessage else { return "tram.fill" }
        if msg.contains("Slow") { return "clock" }
        if msg.localizedCaseInsensitiveContains("location") { return "location.slash" }
        if msg.contains("Bay Area") { return "location.slash" }
        return "tram.fill"
    }

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(WidgetTheme.muted)
            Text(errorMessage ?? "No departures")
                .font(.system(size: 12))
                .foregroundStyle(WidgetTheme.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: DepartureTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let departure = entry.departures.first,
               departure.expectedArrival > entry.date {
                if let stopName = entry.stopName {
                    StopHeader(stopName: stopName)
                        .padding(.bottom, 8)
                }

                Spacer()

                Text(departure.lineName)
                    .font(.system(size: 32, design: .monospaced))
                    .fontWeight(.heavy)
                    .foregroundStyle(WidgetTheme.primary)

                Text(departure.destination)
                    .font(.system(size: 13))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                HStack(alignment: .firstTextBaseline) {
                    let minutes = Int(departure.expectedArrival.timeIntervalSince(entry.date) / 60)
                    Text("\(minutes)")
                        .font(.system(size: 28, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(WidgetTheme.secondary)
                    Text("min")
                        .font(.system(size: 13))
                        .foregroundStyle(WidgetTheme.muted)
                }

                // Second departure if available
                if entry.departures.count > 1 {
                    let next = entry.departures[1]
                    if next.expectedArrival > entry.date {
                        Text("then \(next.lineName) in \(next.minutesAway)m")
                            .font(.system(size: 11))
                            .foregroundStyle(WidgetTheme.muted)
                            .padding(.top, 2)
                    }
                }
            } else {
                WidgetEmptyState(errorMessage: entry.errorMessage, stopName: entry.stopName)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(WidgetTheme.background, for: .widget)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: DepartureTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !entry.departures.isEmpty {
                // Header
                HStack {
                    if let stopName = entry.stopName {
                        StopHeader(stopName: stopName)
                    }
                    Spacer()
                    Text("BAY AREA TRANSIT")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.muted.opacity(0.6))
                }
                .padding(.bottom, 8)

                // Departures
                ForEach(Array(entry.departures.prefix(4).enumerated()), id: \.element.id) { index, departure in
                    DepartureRow(departure: departure, entryDate: entry.date, isNext: index == 0)
                    if index < min(entry.departures.count, 4) - 1 {
                        Divider()
                            .background(WidgetTheme.border)
                    }
                }
            } else {
                WidgetEmptyState(errorMessage: entry.errorMessage, stopName: entry.stopName)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WidgetTheme.background, for: .widget)
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: DepartureTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !entry.departures.isEmpty {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BAY AREA TRANSIT")
                            .font(.system(size: 10, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(WidgetTheme.muted)
                        if let stopName = entry.stopName {
                            Text(stopName)
                                .font(.system(size: 16, design: .serif))
                                .italic()
                                .foregroundStyle(WidgetTheme.textPrimary)
                        }
                    }
                    Spacer()
                    Image(systemName: "tram.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(WidgetTheme.primary)
                }
                .padding(.bottom, 16)

                // Departure board
                VStack(spacing: 0) {
                    ForEach(Array(entry.departures.prefix(6).enumerated()), id: \.element.id) { index, departure in
                        DepartureRow(departure: departure, entryDate: entry.date, isNext: index == 0)
                        if index < min(entry.departures.count, 6) - 1 {
                            Divider()
                                .background(WidgetTheme.border)
                        }
                    }
                }
                .padding(12)
                .background(WidgetTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(WidgetTheme.border, lineWidth: 1)
                )

                Spacer()

                // Footer
                Text("Made with love in San Francisco")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(WidgetTheme.muted.opacity(0.5))
                    .frame(maxWidth: .infinity)
            } else {
                WidgetEmptyState(errorMessage: entry.errorMessage, stopName: entry.stopName)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WidgetTheme.background, for: .widget)
    }
}
