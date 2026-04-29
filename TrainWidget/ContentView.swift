import SwiftUI
import WidgetKit

struct ContentView: View {
    @ObservedObject var locationManager: LocationManager

    @State private var enabledAgencies: Set<TransitAgency> = Set(UserDefaultsStore.enabledAgencies)
    @State private var starredLines: Set<String> = Set(UserDefaultsStore.starredLines)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    contentSections
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .tint(AppTheme.primary)
        }
        .task {
            // Refresh MUNI stops cache on launch if any MUNI agency is enabled
            // The bundled stops.json only has one direction per stop —
            // the API gives us both directions
            if enabledAgencies.contains(.muniBus) || enabledAgencies.contains(.muniMetro) {
                refreshStopsIfNeeded()
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            let totalHeight = AppTheme.heroHeight + topInset

            ZStack(alignment: .bottomLeading) {
                Image("hero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: totalHeight, alignment: .top)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color(red: 0.118, green: 0.165, blue: 0.118).opacity(0.1),
                        Color(red: 0.118, green: 0.165, blue: 0.118).opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("BAY AREA TRANSIT")
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(2.5)
                        .foregroundStyle(Color(red: 0.894, green: 0.867, blue: 0.816).opacity(0.75))

                    Text("Departures at a glance")
                        .font(.system(size: 22, design: .serif))
                        .italic()
                        .foregroundStyle(Color(red: 0.894, green: 0.867, blue: 0.816))
                }
                .padding(.leading, AppTheme.spacingXL)
                .padding(.bottom, AppTheme.spacingLG)
            }
            .frame(height: totalHeight)
            .clipped()
        }
        .frame(height: AppTheme.heroHeight)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Content Sections

    private var contentSections: some View {
        VStack(spacing: AppTheme.spacingXXL) {
            agenciesSection
            settingsLink
            footerHint
        }
        .padding(.horizontal, AppTheme.spacingXL)
        .padding(.top, AppTheme.spacingXXL)
        .padding(.bottom, AppTheme.spacingXXL)
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, design: .monospaced))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.muted)
    }

    // MARK: - Card Container

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(AppTheme.spacingLG)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusCard)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Agencies Section

    private var agenciesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionLabel("Agencies")
            card {
                ForEach(Array(TransitAgency.allCases.enumerated()), id: \.element) { index, agency in
                    agencyRow(agency)
                    if index < TransitAgency.allCases.count - 1 {
                        Divider()
                            .background(AppTheme.border)
                            .padding(.vertical, AppTheme.spacingSM)
                    }
                }
            }
        }
    }

    private func agencyRow(_ agency: TransitAgency) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agency.displayName)
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(agency.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Toggle("", isOn: agencyBinding(for: agency))
                    .labelsHidden()
                    .tint(AppTheme.primary)
            }
            .padding(.vertical, AppTheme.spacingXS)

            if enabledAgencies.contains(agency) && !agency.knownLines.isEmpty {
                lineChips(for: agency)
                    .padding(.top, AppTheme.spacingMD)
                    .padding(.bottom, AppTheme.spacingSM)
            }
        }
    }

    private func lineChips(for agency: TransitAgency) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
                .opacity(0.5)
                .padding(.bottom, AppTheme.spacingLG)

            FlowLayout(spacing: 10) {
                ForEach(agency.knownLines, id: \.self) { line in
                    lineChip(line: line, isStarred: starredLines.contains(line))
                        .onTapGesture {
                            toggleStarred(line)
                        }
                }
            }
        }
    }

    private func lineChip(line: String, isStarred: Bool) -> some View {
        Text(isStarred ? "\(line) ★" : line)
            .font(.system(size: 12, design: .monospaced))
            .fontWeight(isStarred ? .bold : .regular)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isStarred ? .white : AppTheme.textPrimary)
            .background(isStarred ? AppTheme.primary : AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusChip))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusChip)
                    .stroke(isStarred ? Color.clear : AppTheme.border, lineWidth: 1)
            )
    }

    // MARK: - Settings Link

    private var settingsLink: some View {
        NavigationLink {
            SetupView(locationManager: locationManager)
        } label: {
            card {
                HStack {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.muted)
                    Text("Setup")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerHint: some View {
        Text("Made with love in San Francisco")
            .font(.system(size: 11, design: .serif))
            .italic()
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func agencyBinding(for agency: TransitAgency) -> Binding<Bool> {
        Binding(
            get: { enabledAgencies.contains(agency) },
            set: { enabled in
                if enabled {
                    enabledAgencies.insert(agency)
                    // Fetch full MUNI stops when any MUNI agency is enabled
                    if agency == .muniBus || agency == .muniMetro {
                        refreshStopsIfNeeded()
                    }
                } else {
                    enabledAgencies.remove(agency)
                }
                UserDefaultsStore.enabledAgencies = Array(enabledAgencies)
                WidgetCenter.shared.reloadAllTimelines()
            }
        )
    }

    private func refreshStopsIfNeeded() {
        let apiKey = UserDefaultsStore.apiKey ?? ""
        guard !apiKey.isEmpty, StopData.cacheNeedsRefresh else { return }
        Task {
            await StopData.refreshMuniBusStops(apiKey: apiKey)
        }
    }

    private func toggleStarred(_ line: String) {
        if starredLines.contains(line) {
            starredLines.remove(line)
        } else {
            starredLines.insert(line)
        }
        UserDefaultsStore.starredLines = Array(starredLines)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

#Preview {
    ContentView(locationManager: LocationManager())
}
