import SwiftUI

struct FavoriteSongsView: View {
  @ObservedObject var viewModel: PlaylistsViewModel
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    Group {
      if viewModel.favoriteSongs.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "star")
            .font(.system(size: 36))
            .foregroundColor(.secondary)
          Text("No favorites yet")
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(viewModel.favoriteSongs) { song in
          Button {
            audioManager.play(song: song, context: viewModel.favoriteSongs)
          } label: {
            SongRow(song: song, size: .regular)
          }
          .buttonStyle(PressableButtonStyle())
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
      }
    }
    .navigationTitle("Favorites")
    .onAppear { viewModel.fetchFavoriteSongs() }
  }
}
