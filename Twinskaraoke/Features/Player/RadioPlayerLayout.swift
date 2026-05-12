import SwiftUI

struct RadioPlayerLayout: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  @ObservedObject var favorites: FavoritesManager
  @Binding var showingQueue: Bool
  let song: Song
  let artSize: CGFloat
  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 8)
      PlayerArtworkView(song: song, size: artSize)
      Spacer(minLength: 28)
      headerRow
        .padding(.horizontal, 32)
      Spacer(minLength: 24)
      playStopButton
      Spacer(minLength: 24)
      PlayerVolumeRow()
      PlayerBottomToolbar(
        showingQueue: $showingQueue,
        song: song,
        onLyricsToggle: {},
        showLyrics: false
      )
      Spacer(minLength: 8)
    }
  }
  private var headerRow: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Circle()
            .fill(Color.appAccent)
            .frame(width: 7, height: 7)
            .scaleEffect(audioManager.isPlaying ? 1.0 : 0.6)
            .animation(
              audioManager.isPlaying
                ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                : .default,
              value: audioManager.isPlaying
            )
          Text("LIVE RADIO")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.appAccent)
            .tracking(1.2)
          if let listeners = RadioController.shared.nowPlaying?.listeners {
            Text("·")
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(.secondary.opacity(0.7))
            Text("\(listeners.unique) listening")
              .font(.system(size: 11))
              .foregroundColor(.secondary)
          }
        }
        MarqueeText(
          text: song.title,
          font: .system(size: 22, weight: .bold),
          color: .primary
        )
        Text(song.displayArtist)
          .font(.system(size: 17))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      if canFavoriteRadioSong, let songID = radioFavoriteID {
        Button {
          favorites.toggle(songID: songID)
        } label: {
          Group {
            let isFav = favorites.isFavorite(songID)
            if #available(iOS 17.0, *) {
              Image(systemName: isFav ? "star.fill" : "star")
                .contentTransition(.symbolEffect(.replace))
            } else {
              Image(systemName: isFav ? "star.fill" : "star")
            }
          }
          .font(.system(size: 24, weight: .regular))
          .foregroundColor(favorites.isFavorite(songID) ? .appAccent : .primary)
          .frame(width: 36, height: 36)
          .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.88, dim: 0.6))
      }
    }
  }
  private var playStopButton: some View {
    Button {
      audioManager.togglePlayPause()
    } label: {
      Group {
        if #available(iOS 17.0, *) {
          Image(systemName: audioManager.isPlaying ? "stop.fill" : "play.fill")
            .contentTransition(.symbolEffect(.replace))
        } else {
          Image(systemName: audioManager.isPlaying ? "stop.fill" : "play.fill")
        }
      }
      .font(.system(size: 56, weight: .regular))
      .foregroundColor(.primary)
      .frame(width: 88, height: 88)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableButtonStyle(scale: 0.9, dim: 0.6))
  }
  private var radioFavoriteID: String? {
    RadioController.shared.nowPlaying?.nowPlaying?.song.resolvedSongID
  }
  private var canFavoriteRadioSong: Bool {
    radioFavoriteID != nil
  }
}
