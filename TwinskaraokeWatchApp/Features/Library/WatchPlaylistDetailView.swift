import SwiftUI

struct WatchPlaylistDetailView: View {
  @StateObject var viewModel: WatchPlaylistDetailViewModel
  @EnvironmentObject var audioManager: WatchAudioManager
  @State private var showPlayer = false
  let playlistName: String
  init(playlistID: String, playlistName: String) {
    self.playlistName = playlistName
    _viewModel = StateObject(wrappedValue: WatchPlaylistDetailViewModel(playlistID: playlistID))
  }
  var body: some View {
    List {
      if viewModel.isLoading && viewModel.songs.isEmpty {
        HStack {
          Spacer()
          ProgressView()
          Spacer()
        }
      } else {
        ForEach(viewModel.songs) { song in
          Button {
            audioManager.play(song: song, context: viewModel.songs)
            showPlayer = true
          } label: {
            HStack(spacing: 10) {
              AsyncImage(url: song.imageURL) { image in
                image.resizable().scaledToFill()
              } placeholder: {
                Color.secondary.opacity(0.15)
              }
              .frame(width: 40, height: 40)
              .cornerRadius(4)
              VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                  .font(.system(size: 14, weight: .medium))
                  .foregroundColor(audioManager.currentSong?.id == song.id ? .appAccent : .primary)
                  .lineLimit(1)
                HStack {
                  Text(song.artistName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                  Spacer()
                  Text(song.durationText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
              }
            }
            .padding(.vertical, 4)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .navigationTitle(playlistName)
    .navigationDestination(isPresented: $showPlayer) {
      WatchPlayerView()
        .environmentObject(audioManager)
    }
    .onAppear {
      viewModel.fetchSongs()
    }
  }
}
