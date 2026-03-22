import SwiftUI
import RevenueCat

@main
struct SimastryAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
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
