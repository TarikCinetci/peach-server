import SwiftUI

enum Theme {
    static let accent = Color(red: 1.0, green: 0.56, blue: 0.42)
    static let accent2 = Color(red: 1.0, green: 0.36, blue: 0.52)
    static let base = Color(red: 0.075, green: 0.04, blue: 0.055)
    static let gradient = LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Koyu zemin üzerinde yumuşak renk lekeleri; cam yüzeylerin arkasında derinlik verir.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.base
            Circle().fill(Theme.accent.opacity(0.55)).frame(width: 340).blur(radius: 110).offset(x: -140, y: -300)
            Circle().fill(Theme.accent2.opacity(0.38)).frame(width: 300).blur(radius: 120).offset(x: 160, y: -80)
            Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.35).opacity(0.28)).frame(width: 320).blur(radius: 130).offset(x: -80, y: 380)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Liquid Glass kart.
    func glassCard(cornerRadius: CGFloat = 26) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
