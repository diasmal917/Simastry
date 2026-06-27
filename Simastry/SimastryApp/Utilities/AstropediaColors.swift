import SwiftUI

struct AstropediaColors {
    static let backgroundTop = Color(red: 11/255, green: 26/255, blue: 46/255)
    static let backgroundBottom = Color(red: 19/255, green: 46/255, blue: 61/255)
    static let gold = Color(red: 184/255, green: 150/255, blue: 12/255)
    static let text = Color(red: 212/255, green: 145/255, blue: 58/255)
    static let ringStroke = Color(red: 184/255, green: 150/255, blue: 12/255).opacity(0.2)

    static var background: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
