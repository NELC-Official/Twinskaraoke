import SwiftUI

extension Color {
  static let appAccent = Color(red: 0.99, green: 0.19, blue: 0.35) // #FC3158 — Apple Music pink-red
  static let topPickGradientStart = Color(red: 83/255, green: 83/255, blue: 83/255)
  static let topPickGradientEnd = Color(red: 36/255, green: 36/255, blue: 36/255)
}

struct TopPickGradient: ViewModifier {
  func body(content: Content) -> some View {
    content.background(
      LinearGradient(
        colors: [.topPickGradientStart, .topPickGradientEnd],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
      )
    )
  }
}
