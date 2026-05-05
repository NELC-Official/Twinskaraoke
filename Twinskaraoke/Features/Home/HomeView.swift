import SwiftUI

struct HomeView: View {
  @StateObject var viewModel = HomeViewModel()
  @StateObject private var recentlyPlayed = RecentlyPlayedStore.shared
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    NavigationStack {
      ScrollView {
        Group {
          if viewModel.isLoading {
            HomeSkeletonView()
              .transition(.opacity)
          } else {
            VStack(alignment: .leading, spacing: 28) {
              if !viewModel.recentPlaylists.isEmpty {
                PlaylistCarousel(title: "Top Picks", playlists: viewModel.recentPlaylists)
              }
              if !recentlyPlayed.playlists.isEmpty {
                PlaylistCarousel(title: "Recently Played", playlists: recentlyPlayed.playlists)
              }
              if !viewModel.suggestions.isEmpty {
                HomeSongSection(title: "Made for You", songs: viewModel.suggestions)
              }
              HomePlaceholderSection(
                title: "New Releases",
                tiles: HomePlaceholderTile.newReleases
              )
              HomePlaceholderSection(
                title: "Stations for You",
                tiles: HomePlaceholderTile.stations,
                style: .station
              )
              if !viewModel.trending.isEmpty {
                HomeSongSection(title: "More to Explore", songs: viewModel.trending)
              }
            }
            .transition(.opacity)
          }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isLoading)
        .padding(.vertical)
        .padding(.bottom, 16)
      }
      .navigationTitle("Home")
      .onAppear { viewModel.fetchHomeData() }
    }
  }
}

struct PlaylistCarousel: View {
  let title: String
  let playlists: [Playlist]
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      NavigationLink(destination: PlaylistListView(title: title, playlists: playlists)) {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.primary)
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }
      }
      .buttonStyle(.plain)
      .padding(.leading, 15)
      .padding(.trailing)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(playlists) { playlist in
            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
              VStack(alignment: .leading, spacing: 6) {
                LoadingImage(url: playlist.imageURL, cornerRadius: 10)
                  .frame(width: 170, height: 170)
                  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(playlist.name)
                  .font(.system(size: 15, weight: .semibold))
                  .foregroundColor(.primary)
                  .lineLimit(1)
                Text("\(playlist.songCount) songs")
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
              .frame(width: 170)
            }
            .buttonStyle(PressableButtonStyle())
          }
        }
        .padding(.horizontal)
      }
    }
  }
}

struct PlaylistListView: View {
  let title: String
  let playlists: [Playlist]
  let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
  var body: some View {
    ScrollView {
      LazyVGrid(columns: cols, spacing: 16) {
        ForEach(playlists) { playlist in
          NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
            PlaylistGridCell(playlist: playlist)
          }
          .buttonStyle(PressableButtonStyle())
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct HomeSongSection: View {
  let title: String
  let songs: [Song]
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      NavigationLink(destination: SongListView(title: title, songs: songs)) {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.primary)
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }
      }
      .buttonStyle(.plain)
      .padding(.leading, 15)
      .padding(.trailing)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(songs) { song in
            HomeSongCard(song: song, context: songs)
          }
        }
        .padding(.horizontal)
      }
    }
  }
}

struct HomeSongCard: View {
  let song: Song
  let context: [Song]
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    Button {
      audioManager.play(song: song, context: context)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        LoadingImage(url: song.imageURL, cornerRadius: 10)
          .frame(width: 170, height: 170)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        Text(song.title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.primary)
          .lineLimit(1)
        Text(song.displayArtist)
          .font(.system(size: 12))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      .frame(width: 170)
    }
    .buttonStyle(PressableButtonStyle())
  }
}

struct HomePlaceholderTile: Identifiable {
  let id = UUID()
  let title: String
  let subtitle: String
  let gradient: [Color]
  static let newReleases: [HomePlaceholderTile] = [
    .init(title: "Latest Singles", subtitle: "Updated daily", gradient: [Color(red: 0.96, green: 0.30, blue: 0.45), Color(red: 0.55, green: 0.10, blue: 0.30)]),
    .init(title: "New Albums", subtitle: "This week", gradient: [Color(red: 0.20, green: 0.55, blue: 0.95), Color(red: 0.10, green: 0.20, blue: 0.55)]),
    .init(title: "Coming Soon", subtitle: "Pre-add now", gradient: [Color(red: 0.95, green: 0.45, blue: 0.10), Color(red: 0.55, green: 0.15, blue: 0.05)]),
  ]
  static let stations: [HomePlaceholderTile] = [
    .init(title: "Pop Station", subtitle: "Today's biggest hits", gradient: [Color(red: 0.90, green: 0.20, blue: 0.55), Color(red: 0.40, green: 0.05, blue: 0.30)]),
    .init(title: "Hip-Hop Station", subtitle: "Curated for you", gradient: [Color(red: 0.60, green: 0.30, blue: 0.95), Color(red: 0.20, green: 0.05, blue: 0.45)]),
    .init(title: "Chill Station", subtitle: "Easy listening", gradient: [Color(red: 0.10, green: 0.75, blue: 0.85), Color(red: 0.05, green: 0.30, blue: 0.45)]),
  ]
}

struct HomePlaceholderSection: View {
  enum Style { case card, station }
  let title: String
  let tiles: [HomePlaceholderTile]
  var style: Style = .card
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(title)
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.primary)
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.secondary)
        Spacer()
      }
      .padding(.leading, 15)
      .padding(.trailing)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(tiles) { tile in
            HomePlaceholderTileView(tile: tile, style: style)
          }
        }
        .padding(.horizontal)
      }
    }
  }
}

private struct HomePlaceholderTileView: View {
  let tile: HomePlaceholderTile
  let style: HomePlaceholderSection.Style
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ZStack(alignment: .bottomLeading) {
        LinearGradient(colors: tile.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        if style == .station {
          Image(systemName: "dot.radiowaves.left.and.right")
            .font(.system(size: 28, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .padding(12)
        }
      }
      .frame(width: 170, height: 170)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      Text(tile.title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.primary)
        .lineLimit(1)
      Text(tile.subtitle)
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
    .frame(width: 170)
  }
}

struct HomeSkeletonView: View {
  var body: some View {
    LoadingIndicator(size: 64)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.top, 80)
  }
}
