import SwiftUI

struct CelestialBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SimastryColor.pureBlack,
                    Color(red: 5/255, green: 7/255, blue: 18/255),
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
