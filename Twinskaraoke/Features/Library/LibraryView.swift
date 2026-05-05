import SwiftUI

struct LibraryView: View {
  @StateObject var viewModel = PlaylistsViewModel()
  let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            PlaylistsGridScreen(viewModel: viewModel)
          } label: {
            LibraryRow(icon: "music.note.list", color: .appAccent, title: "Playlists")
          }
          NavigationLink {
            LibraryPlaceholderView(title: "Artists", systemImage: "music.mic")
          } label: {
            LibraryRow(icon: "music.mic", color: .appAccent, title: "Artists")
          }
          NavigationLink {
            LibraryPlaceholderView(title: "Albums", systemImage: "square.stack")
          } label: {
            LibraryRow(icon: "square.stack", color: .appAccent, title: "Albums")
          }
          NavigationLink {
            LibraryPlaceholderView(title: "Songs", systemImage: "music.note")
          } label: {
            LibraryRow(icon: "music.note", color: .appAccent, title: "Songs")
          }
          NavigationLink {
            FavoriteSongsView(viewModel: viewModel)
          } label: {
            LibraryRow(icon: "star.fill", color: .appAccent, title: "Favorites")
          }
          NavigationLink {
            LibraryPlaceholderView(title: "Made For You", systemImage: "sparkles")
          } label: {
            LibraryRow(icon: "sparkles", color: .appAccent, title: "Made For You")
          }
          NavigationLink {
            LibraryPlaceholderView(title: "Music Videos", systemImage: "play.rectangle")
          } label: {
            LibraryRow(icon: "play.rectangle", color: .appAccent, title: "Music Videos")
          }
          NavigationLink {
            LibraryPlaceholderView(title: "Genres", systemImage: "guitars")
          } label: {
            LibraryRow(icon: "guitars", color: .appAccent, title: "Genres")
          }
          NavigationLink {
            LibraryPlaceholderView(title: "Composers", systemImage: "music.quarternote.3")
          } label: {
            LibraryRow(icon: "music.quarternote.3", color: .appAccent, title: "Composers")
          }
          NavigationLink {
            LibraryPlaceholderView(title: "Compilations", systemImage: "rectangle.stack")
          } label: {
            LibraryRow(icon: "rectangle.stack", color: .appAccent, title: "Compilations")
          }
          NavigationLink {
            DownloadedSongsView()
          } label: {
            LibraryRow(icon: "arrow.down.circle.fill", color: .appAccent, title: "Downloaded")
          }
          NavigationLink {
            RandomSongsView()
          } label: {
            LibraryRow(icon: "shuffle", color: .appAccent, title: "Random Songs")
          }
        }
        if !viewModel.playlists.isEmpty {
          Section("Recently Added") {
            ForEach(viewModel.playlists.prefix(8)) { playlist in
              NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                PlaylistListRow(playlist: playlist)
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Library")
      .onAppear {
        viewModel.fetchPlaylists()
        viewModel.fetchFavoriteSongs()
      }
    }
  }
}

struct LibraryRow: View {
  let icon: String
  let color: Color
  let title: String
  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 20, weight: .medium))
        .foregroundColor(color)
        .frame(width: 28)
      Text(title)
        .font(.system(size: 17))
      Spacer()
    }
    .padding(.vertical, 4)
  }
}

struct PlaylistListRow: View {
  let playlist: Playlist
  var body: some View {
    HStack(spacing: 12) {
      LoadingImage(url: playlist.imageURL, cornerRadius: 6)
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(playlist.name)
          .font(.system(size: 15, weight: .medium))
          .lineLimit(1)
        Text("\(playlist.songCount) songs")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
      Spacer()
    }
    .padding(.vertical, 2)
  }
}

struct PlaylistsGridScreen: View {
  @ObservedObject var viewModel: PlaylistsViewModel
  let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
  var body: some View {
    ScrollView {
      Group {
        if viewModel.isLoading && viewModel.playlists.isEmpty {
          PlaylistsSkeletonView(cols: cols)
        } else if viewModel.playlists.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "music.note.list")
              .font(.system(size: 48))
              .foregroundColor(.secondary)
            Text("No playlists yet")
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 80)
        } else {
          LazyVGrid(columns: cols, spacing: 16) {
            ForEach(viewModel.playlists) { playlist in
              NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                PlaylistGridCell(playlist: playlist)
              }
              .buttonStyle(PressableButtonStyle())
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
      }
    }
    .navigationTitle("Playlists")
  }
}

struct PlaylistGridCell: View {
  let playlist: Playlist
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      LoadingImage(url: playlist.imageURL, cornerRadius: 10)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
      Text(playlist.name)
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(.primary)
        .lineLimit(1)
      Text("\(playlist.songCount) songs")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct LibraryPlaceholderView: View {
  let title: String
  let systemImage: String
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: systemImage)
        .font(.system(size: 48))
        .foregroundColor(.secondary)
      Text("No \(title) Yet")
        .font(.system(size: 18, weight: .semibold))
      Text("Items you add will appear here.")
        .font(.system(size: 14))
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct PlaylistsSkeletonView: View {
  let cols: [GridItem]
  var body: some View {
    LoadingIndicator(size: 64)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.top, 80)
  }
}
