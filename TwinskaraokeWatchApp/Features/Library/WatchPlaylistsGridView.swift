import SwiftUI

struct WatchPlaylistsGridView: View {
  @StateObject var viewModel = WatchPlaylistsViewModel()
  let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
  ]
  var body: some View {
    ScrollView {
      if viewModel.isLoading && viewModel.playlists.isEmpty {
        ProgressView()
          .padding(.top, 20)
      } else {
        LazyVGrid(columns: columns, spacing: 12) {
          ForEach(viewModel.playlists) { playlist in
            NavigationLink(
              destination: WatchPlaylistDetailView(
                playlistID: playlist.id, playlistName: playlist.name)
            ) {
              VStack(spacing: 6) {
                AsyncImage(url: playlist.imageURL) { image in
                  image.resizable().scaledToFill()
                } placeholder: {
                  Color.secondary.opacity(0.15)
                }
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
                VStack(spacing: 2) {
                  Text(playlist.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                  Text("\(playlist.songCount) songs")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
                .fixedSize(horizontal: false, vertical: true)
              }
              .padding(8)
              .frame(maxWidth: .infinity)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .padding(.horizontal, 8)
      }
    }
    .navigationTitle("Playlists")
    .onAppear {
      viewModel.fetchMusic()
    }
  }
}
