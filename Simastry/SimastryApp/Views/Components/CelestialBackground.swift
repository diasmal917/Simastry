import SwiftUI

struct CelestialBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SimastryColor.midnight,
                    Color(red: 15/255, green: 22/255, blue: 41/255),
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
