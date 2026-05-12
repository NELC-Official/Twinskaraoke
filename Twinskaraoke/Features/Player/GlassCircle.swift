import SwiftUI

struct GlassCircle: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(in: Circle())
    } else {
      content.background(.white.opacity(0.12), in: Circle())
    }
  }
}
