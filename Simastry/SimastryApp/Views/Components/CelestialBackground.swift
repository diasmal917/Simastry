import SwiftUI

struct CelestialBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SimastryColor.midnight,
                    SimastryColor.nightHorizon,
                    SimastryColor.midnight
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            StarfieldView()
                .ignoresSafeArea()
        }
    }
}
