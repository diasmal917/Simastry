import SwiftUI
import SwissEphemeris

@main
struct SimastryAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        BirthChartService.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
