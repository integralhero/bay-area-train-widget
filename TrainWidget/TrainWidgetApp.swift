import SwiftUI

@main
struct TrainWidgetApp: App {
    @StateObject private var locationManager = LocationManager()

    init() {
        UserDefaultsStore.migrateIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(locationManager: locationManager)
        }
    }
}
