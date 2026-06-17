import SwiftUI
import RevenueCat
import SwissEphemeris

@main
struct SimastryAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        BirthChartService.setup()

        let rcKey = AppConfig.revenueCatAPIKey
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
