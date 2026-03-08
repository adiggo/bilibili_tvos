import SwiftUI

extension Color {
    static let bilibiliPink = Color(red: 251/255, green: 114/255, blue: 153/255)
}

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
    }
}

struct AppDebug {
    static let isEnabled = false
}
