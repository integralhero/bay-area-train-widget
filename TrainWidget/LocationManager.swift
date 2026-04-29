import CoreLocation
import Foundation
import UIKit
import WidgetKit

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var status: Status = .idle

    enum Status: Equatable {
        case idle
        case requesting
        case located(latitude: Double, longitude: Double)
        case denied
        case error(String)

        static func == (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.requesting, .requesting), (.denied, .denied): return true
            case let (.located(a, b), .located(c, d)): return a == c && b == d
            case let (.error(a), .error(b)): return a == b
            default: return false
            }
        }
    }

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.allowsBackgroundLocationUpdates = true
        requestLocation()
    }

    func requestLocation() {
        status = .requesting

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            manager.startMonitoringSignificantLocationChanges()
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            manager.startMonitoringSignificantLocationChanges()
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .error("Unknown authorization status")
        }
    }

    private func cacheLocation(_ location: CLLocation) {
        UserDefaultsStore.setCachedLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        status = .located(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            cacheLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            status = .error(error.localizedDescription)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse:
                manager.startMonitoringSignificantLocationChanges()
                manager.requestAlwaysAuthorization()
            case .authorizedAlways:
                manager.startMonitoringSignificantLocationChanges()
            case .denied, .restricted:
                status = .denied
            default:
                break
            }
        }
    }
}
