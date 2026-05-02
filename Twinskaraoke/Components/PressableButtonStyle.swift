import SwiftUI

struct PressableButtonStyle: ButtonStyle {
  var scale: CGFloat = 0.97
  var dim: Double = 0.7
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? scale : 1.0)
      .opacity(configuration.isPressed ? dim : 1.0)
      .animation(
        .spring(response: 0.32, dampingFraction: 0.7), value: configuration.isPressed)
  }
}
