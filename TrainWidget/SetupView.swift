import SwiftUI
import WidgetKit

struct SetupView: View {
    @ObservedObject var locationManager: LocationManager
    @AppStorage("apiKey", store: UserDefaultsStore.defaults)
    private var apiKey: String = ""

    @State private var testResult: String?
    @State private var debugResult: String?
    @State private var isTesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingXXL) {
                connectionSection
                locationSection
                testSection
            }
            .padding(.horizontal, AppTheme.spacingXL)
            .padding(.top, AppTheme.spacingXXL)
            .padding(.bottom, AppTheme.spacingXXL)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.primary)
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

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionLabel("API Key")
            card {
                SecureField("Enter your 511.org API key", text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusInput))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusInput)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .onChange(of: apiKey) {
                        UserDefaultsStore.apiKey = apiKey
                        // Flush any cached response keyed to the previous key
                        // so the next fetch validates the new one live.
                        DepartureCache.clear()
                        WidgetCenter.shared.reloadAllTimelines()
                    }

                Link(destination: URL(string: "https://511.org/open-data/token")!) {
                    Text("Get a free key at 511.org →")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.primary)
                        .underline(true, color: AppTheme.primary.opacity(0.5))
                }
                .padding(.top, AppTheme.spacingMD)
            }
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionLabel("Location")
            card {
                HStack {
                    locationStatusContent
                    Spacer()
                    Button(action: { locationManager.requestLocation() }) {
                        Text("Update")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusInput))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusInput)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var locationStatusContent: some View {
        switch locationManager.status {
        case .idle:
            if UserDefaultsStore.hasLocation {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.success)
                        .font(.system(size: 13))
                    Text(String(format: "%.4f, %.4f",
                                UserDefaultsStore.cachedLatitude ?? 0,
                                UserDefaultsStore.cachedLongitude ?? 0))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            } else {
                Text("No location set")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
            }
        case .requesting:
            Text("Getting location...")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.primary)
        case let .located(lat, lon):
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .foregroundStyle(AppTheme.success)
                    .font(.system(size: 13))
                Text(String(format: "%.4f, %.4f", lat, lon))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        case .denied:
            Text("Location denied — enable in Settings")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.error)
        case let .error(msg):
            Text("Error: \(msg)")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.error)
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(spacing: AppTheme.spacingMD) {
            Button(action: testAPI) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Test Connection")
                            .font(.system(size: 13, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(AppTheme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusButton))
            }
            .disabled(apiKey.isEmpty || !UserDefaultsStore.hasLocation || isTesting)
            .opacity(apiKey.isEmpty || !UserDefaultsStore.hasLocation ? 0.5 : 1)

            if let result = testResult {
                HStack(spacing: 6) {
                    Image(systemName: result.contains("Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                    Text(result)
                }
                .font(.system(size: 12))
                .foregroundStyle(result.contains("Error") ? AppTheme.error : AppTheme.success)
            }

            if let debug = debugResult {
                DisclosureGroup("Debug Details") {
                    Text(debug)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.muted)
                        .textSelection(.enabled)
                }
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.muted)
            }
        }
    }

    // MARK: - Test API

    private func testAPI() {
        guard let lat = UserDefaultsStore.cachedLatitude,
              let lon = UserDefaultsStore.cachedLongitude else { return }

        isTesting = true
        testResult = nil
        debugResult = nil

        // Always read fresh from UserDefaults
        let enabledAgencies = UserDefaultsStore.enabledAgencies

        Task {
            do {
                let stops = StopData.loadStops()
                var debugLines = ""
                var allDepartures: [Departure] = []

                for agency in enabledAgencies {
                    let nearest = StopFinder.nearestStops(
                        latitude: lat, longitude: lon,
                        stops: stops, agencies: [agency],
                        maxDistance: StopFinder.maxRangeMeters
                    )

                    if nearest.isEmpty {
                        debugLines += "\(agency.displayName): No stops in range\n"
                        continue
                    }

                    for stop in nearest {
                        let debug1 = try await TransitAPI.debugFetch(
                            apiKey: apiKey, agency: agency, stopCode: stop.id
                        )
                        debugLines += "\(agency.displayName): \(stop.name) (id=\(stop.id))\n\(debug1)\n"
                        if let altId = stop.altId {
                            let debug2 = try await TransitAPI.debugFetch(
                                apiKey: apiKey, agency: agency, stopCode: altId
                            )
                            debugLines += "Alt (id=\(altId)): \(debug2)\n"
                        }

                        let departures = try await TransitAPI.fetchDeparturesForStop(
                            apiKey: apiKey, stop: stop, asAgency: agency
                        )
                        debugLines += "→ \(departures.count) \(agency.displayName) departures after filtering\n\n"
                        allDepartures.append(contentsOf: departures)
                    }
                }
                debugResult = debugLines

                allDepartures.sort { $0.expectedArrival < $1.expectedArrival }
                if allDepartures.isEmpty {
                    if enabledAgencies.isEmpty {
                        testResult = "No agencies enabled"
                    } else {
                        testResult = "No upcoming departures found"
                    }
                } else {
                    let count = allDepartures.count
                    let first = allDepartures[0]
                    testResult = "OK: \(count) departures — next: \(first.lineName) \(first.destination) in \(first.minutesAway)m"
                }
            } catch TransitAPIError.rateLimited {
                testResult = "Error: Rate limited — try again shortly"
            } catch {
                testResult = "Error: \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}

#Preview {
    NavigationStack {
        SetupView(locationManager: LocationManager())
    }
}
