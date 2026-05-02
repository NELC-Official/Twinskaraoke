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
                PlaylistCarousel(title: "Recent Playlists", playlists: viewModel.recentPlaylists)
              }
              if !recentlyPlayed.playlists.isEmpty {
                PlaylistCarousel(title: "Recently Played", playlists: recentlyPlayed.playlists)
              }
              if !viewModel.trending.isEmpty {
                HomeSongSection(title: "Trending", songs: viewModel.trending)
              }
              if !viewModel.suggestions.isEmpty {
                HomeSongSection(title: "Made for You", songs: viewModel.suggestions)
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
            .font(.title2.bold())
            .foregroundColor(.primary)
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }
      }
      .buttonStyle(.plain)
      .padding(.horizontal)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(playlists) { playlist in
            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
              VStack(alignment: .leading, spacing: 6) {
                LoadingImage(url: playlist.imageURL, cornerRadius: 12)
                  .frame(width: 160, height: 160)
                  .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(playlist.name)
                  .font(.system(size: 13, weight: .bold))
                  .foregroundColor(.primary)
                  .lineLimit(1)
                Text("\(playlist.songCount) songs")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
              .frame(width: 160)
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
            .font(.title2.bold())
            .foregroundColor(.primary)
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }
      }
      .buttonStyle(.plain)
      .padding(.horizontal)
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
        LoadingImage(url: song.imageURL, cornerRadius: 12)
          .frame(width: 140, height: 140)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        Text(song.title)
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(.primary)
          .lineLimit(1)
        Text(song.displayArtist)
          .font(.system(size: 11))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      .frame(width: 140)
    }
    .buttonStyle(PressableButtonStyle())
  }
}

struct HomeSkeletonView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      ForEach(0..<3, id: \.self) { _ in
        VStack(alignment: .leading, spacing: 12) {
          ShimmerBox(cornerRadius: 6)
            .frame(width: 130, height: 24)
            .padding(.horizontal)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              ForEach(0..<5, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                  ShimmerBox(cornerRadius: 12)
                    .frame(width: 140, height: 140)
                  ShimmerBox(cornerRadius: 4).frame(width: 110, height: 13)
                  ShimmerBox(cornerRadius: 4).frame(width: 80, height: 11)
                }
                .frame(width: 140)
              }
            }
            .padding(.horizontal)
          }
        }
      }
    }
  }
}
