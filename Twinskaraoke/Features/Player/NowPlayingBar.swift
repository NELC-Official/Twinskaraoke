import SwiftUI

#if canImport(UIKit)
  import UIKit

#endif

struct NowPlayingBar: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    if let song = audioManager.currentSong {
      nowPlayingContent(song: song)
        .contentShape(Rectangle())
        .onTapGesture {
          audioManager.showFullScreen = true
        }
    }
  }
  @ViewBuilder
  private func nowPlayingContent(song: Song) -> some View {
    HStack(spacing: 10) {
      LoadingImage(url: audioManager.displayImageURL(for: song), cornerRadius: 6)
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(.leading, 10)
        .id(song.id)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: song.id)
      VStack(alignment: .leading, spacing: 1) {
        if audioManager.isRadioMode {
          HStack(spacing: 3) {
            Circle().fill(.red).frame(width: 4, height: 4)
            Text("LIVE")
              .font(.system(size: 8, weight: .bold))
              .foregroundColor(.red)
          }
        }
        MarqueeText(
          text: song.title,
          font: .system(size: 14, weight: .regular),
          color: .primary
        )
      }
      Spacer(minLength: 4)
      Button {
        audioManager.togglePlayPause()
      } label: {
        Group {
          if #available(iOS 17.0, *) {
            Image(systemName: playPauseSymbol)
              .contentTransition(.symbolEffect(.replace))
          } else {
            Image(systemName: playPauseSymbol)
              .contentTransition(.opacity)
          }
        }
        .font(.system(size: 20, weight: .regular))
        .foregroundColor(.primary)
        .frame(width: 30, height: 36)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      if !audioManager.isRadioMode {
        Button {
          audioManager.playNextOrRandom()
        } label: {
          Image(systemName: "forward.fill")
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.primary)
            .frame(width: 30, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.trailing, audioManager.isRadioMode ? 14 : 8)
    .frame(height: 56)
    .modifier(NowPlayingBarBackground())
    .padding(.horizontal, 8)
    .padding(.bottom, 0)
  }
  private var playPauseSymbol: String {
    if audioManager.isRadioMode {
      return audioManager.isPlaying ? "stop.fill" : "play.fill"
    }
    return audioManager.isPlaying ? "pause.fill" : "play.fill"
  }
}

private struct NowPlayingBarBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
    } else {
      content
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(
              LinearGradient(
                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing
              ),
              lineWidth: 0.6
            )
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
  }
}

struct MarqueeText: View {
  let text: String
  let font: Font
  let color: Color
  var speed: CGFloat = 35
  var gap: CGFloat = 48
  var startDelay: Double = 1.2
  @State private var textSize: CGSize = .zero
  @State private var containerWidth: CGFloat = 0
  @State private var phase: CGFloat = 0
  @State private var animationTask: Task<Void, Never>?
  private var needsScroll: Bool {
    containerWidth > 0 && textSize.width > containerWidth + 0.5
  }
  var body: some View {
    Text(text)
      .font(font)
      .lineLimit(1)
      .opacity(0)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            if needsScroll {
              HStack(spacing: gap) {
                Text(text).font(font).foregroundColor(color).fixedSize()
                Text(text).font(font).foregroundColor(color).fixedSize()
              }
              .offset(x: -phase)
            } else {
              Text(text).font(font).foregroundColor(color).fixedSize()
            }
          }
          .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
          .clipped()
          .mask(
            LinearGradient(
              stops: needsScroll
                ? [
                  .init(color: .clear, location: 0),
                  .init(color: .black, location: 0.04),
                  .init(color: .black, location: 0.96),
                  .init(color: .clear, location: 1),
                ]
                : [
                  .init(color: .black, location: 0),
                  .init(color: .black, location: 1),
                ],
              startPoint: .leading, endPoint: .trailing
            )
          )
          .onAppear {
            containerWidth = geo.size.width
            restartAnimation()
          }
          .onChange(of: geo.size.width) { newWidth in
            containerWidth = newWidth
            restartAnimation()
          }
        }
      )
      .background(
        Text(text)
          .font(font)
          .fixedSize()
          .hidden()
          .background(
            GeometryReader { t in
              Color.clear.preference(key: TextSizeKey.self, value: t.size)
            })
      )
      .onPreferenceChange(TextSizeKey.self) { size in
        if abs(textSize.width - size.width) > 0.5 {
          textSize = size
          restartAnimation()
        }
      }
      .onChange(of: text) { _ in
        restartAnimation()
      }
      .onDisappear {
        animationTask?.cancel()
      }
  }
  private func restartAnimation() {
    animationTask?.cancel()
    phase = 0
    guard needsScroll else { return }
    let distance = textSize.width + gap
    let duration = Double(distance) / Double(speed)
    animationTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
      while !Task.isCancelled {
        withAnimation(.linear(duration: duration)) {
          phase = distance
        }
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        if Task.isCancelled { break }
        phase = 0
        try? await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
      }
    }
  }
}

private struct TextSizeKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
