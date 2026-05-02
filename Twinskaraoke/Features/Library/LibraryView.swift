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
            FavoriteSongsView(viewModel: viewModel)
          } label: {
            LibraryRow(icon: "star.fill", color: .appAccent, title: "Favorites")
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

struct PlaylistsSkeletonView: View {
  let cols: [GridItem]
  var body: some View {
    LazyVGrid(columns: cols, spacing: 16) {
      ForEach(0..<8, id: \.self) { _ in
        VStack(alignment: .leading, spacing: 6) {
          ShimmerBox(cornerRadius: 10)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
          ShimmerBox(cornerRadius: 4)
            .frame(height: 14)
          HStack {
            ShimmerBox(cornerRadius: 4).frame(width: 80, height: 12)
            Spacer()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}
