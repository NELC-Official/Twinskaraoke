import SDWebImageSwiftUI
import SwiftUI

struct LoadingImage: View {
  let url: URL?
  var cornerRadius: CGFloat = 8
  var contentMode: ContentMode = .fill
  var body: some View {
    GeometryReader { geo in
      WebImage(url: url) { image in
        image
          .resizable()
          .aspectRatio(contentMode: contentMode)
          .frame(width: geo.size.width, height: geo.size.height)
          .clipped()
      } placeholder: {
        ZStack {
          Color(.systemGray5)
          LoadingIndicator(size: min(geo.size.width, geo.size.height) * 0.5)
        }
        .frame(width: geo.size.width, height: geo.size.height)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
  }
}
/// Animated loading indicator using `Loading.webp`. Use anywhere a spinner would normally appear.

struct LoadingIndicator: View {
  var size: CGFloat = 48
  var body: some View {
    AnimatedImage(name: "Loading.webp")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
  }
}

struct ShimmerBox: View {
  var cornerRadius: CGFloat = 8
  @State private var phase: CGFloat = -1
  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(Color(.systemGray5))
      .overlay(
        GeometryReader { geo in
          LinearGradient(
            stops: [
              .init(color: .white.opacity(0), location: 0),
              .init(color: .white.opacity(0.35), location: 0.5),
              .init(color: .white.opacity(0), location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
          )
          .frame(width: geo.size.width * 0.6)
          .offset(x: phase * geo.size.width * 1.6)
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .onAppear {
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
          phase = 1
        }
      }
  }
}
