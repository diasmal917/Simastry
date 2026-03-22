import SwiftUI
import RevenueCat
import SwissEphemeris

@main
struct SimastryAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Initialize Swiss Ephemeris for birth chart calculations
        BirthChartService.setup()

        let rcKey = Config.EXPO_PUBLIC_REVENUECAT_API_KEY
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        if !rcKey.isEmpty {
            Purchases.configure(withAPIKey: rcKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
