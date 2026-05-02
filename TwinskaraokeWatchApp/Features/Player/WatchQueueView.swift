import SwiftUI

struct WatchQueueView: View {
  @EnvironmentObject var audioManager: WatchAudioManager
  var body: some View {
    List {
      if let current = audioManager.currentSong {
        Section("Now Playing") {
          QueueRowCompact(song: current, isCurrent: true)
        }
      }
      let upNext = upNextSongs
      if !upNext.isEmpty {
        Section("Playing Next") {
          ForEach(upNext) { song in
            Button {
              audioManager.play(song: song, context: audioManager.queue)
            } label: {
              QueueRowCompact(song: song, isCurrent: false)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .navigationTitle("Queue")
  }
  private var upNextSongs: [Song] {
    guard let current = audioManager.currentSong,
      let idx = audioManager.queue.firstIndex(of: current),
      idx + 1 < audioManager.queue.count
    else { return [] }
    return Array(audioManager.queue[(idx + 1)...])
  }
}

private struct QueueRowCompact: View {
  let song: Song
  let isCurrent: Bool
  var body: some View {
    HStack(spacing: 8) {
      AsyncImage(url: song.imageURL) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Color.secondary.opacity(0.15)
      }
      .frame(width: 32, height: 32)
      .cornerRadius(4)
      VStack(alignment: .leading, spacing: 1) {
        Text(song.title)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(isCurrent ? .appAccent : .primary)
          .lineLimit(1)
        Text(song.artistName)
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
    }
  }
}
