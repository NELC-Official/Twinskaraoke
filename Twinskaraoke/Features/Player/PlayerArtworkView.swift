import SwiftUI

struct PlayerArtworkView: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  let song: Song
  let size: CGFloat
  var body: some View {
    ZStack {
      LoadingImage(
        url: audioManager.displayImageURL(for: song), cornerRadius: AM.Radius.hero,
        contentMode: .fill
      )
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: AM.Radius.hero, style: .continuous))
      .id(song.id)
      .shadow(
        color: .black.opacity(audioManager.isPlaying ? 0.45 : 0.22),
        radius: audioManager.isPlaying ? 28 : 16,
        y: audioManager.isPlaying ? 18 : 10
      )
      .scaleEffect(audioManager.isPlaying ? 1.0 : 0.86)
      .animation(.spring(response: 0.5, dampingFraction: 0.78), value: audioManager.isPlaying)
      if audioManager.isBuffering {
        RoundedRectangle(cornerRadius: AM.Radius.hero, style: .continuous)
          .fill(Color.black.opacity(0.4))
          .frame(width: size, height: size)
        LoadingIndicator(size: 64)
      }
    }
    .frame(maxWidth: .infinity)
  }
}
