import SwiftUI

struct WatchHomeView: View {
  @StateObject var audioManager = WatchAudioManager.shared
  @StateObject var homeViewModel = WatchHomeViewModel()
  @State private var navigateToPlayer = false
  var body: some View {
    NavigationStack {
      List {
        if audioManager.currentSong != nil {
          Section("Now Playing") {
            NavigationLink(destination: WatchPlayerView().environmentObject(audioManager)) {
              HStack(spacing: 10) {
                if let url = audioManager.currentSong?.imageURL {
                  AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                  } placeholder: {
                    Color.secondary.opacity(0.15)
                  }
                  .frame(width: 36, height: 36)
                  .cornerRadius(4)
                }
                VStack(alignment: .leading, spacing: 2) {
                  Text(audioManager.currentSong?.title ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .lineLimit(1)
                  Text(audioManager.currentSong?.artistName ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
                Spacer()
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                  .font(.system(size: 14))
                  .foregroundColor(.appAccent)
              }
            }
          }
        }
        if !homeViewModel.trending.isEmpty {
          Section("Trending") {
            ForEach(homeViewModel.trending.prefix(5)) { song in
              Button {
                audioManager.play(song: song, context: homeViewModel.trending)
                navigateToPlayer = true
              } label: {
                HStack(spacing: 10) {
                  AsyncImage(url: song.imageURL) { image in
                    image.resizable().scaledToFill()
                  } placeholder: {
                    Color.secondary.opacity(0.15)
                  }
                  .frame(width: 36, height: 36)
                  .cornerRadius(4)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                      .font(.system(size: 13, weight: .medium))
                      .foregroundColor(.primary)
                      .lineLimit(1)
                    Text(song.artistName)
                      .font(.system(size: 11))
                      .foregroundColor(.secondary)
                      .lineLimit(1)
                  }
                }
              }
              .buttonStyle(.plain)
            }
          }
        } else if homeViewModel.isLoading {
          Section("Trending") {
            HStack {
              Spacer()
              ProgressView()
              Spacer()
            }
          }
        }
        Section("Browse") {
          NavigationLink(destination: WatchPlaylistsGridView()) {
            Label("Playlists", systemImage: "music.note.list")
          }
          NavigationLink(destination: WatchSongsView().environmentObject(audioManager)) {
            Label("Songs", systemImage: "music.note")
          }
          NavigationLink(destination: WatchSearchView().environmentObject(audioManager)) {
            Label("Search", systemImage: "magnifyingglass")
          }
          NavigationLink(destination: WatchAccountView()) {
            Label("Account", systemImage: "person.crop.circle")
          }
        }
      }
      .navigationTitle("Twins Karaoke")
      .navigationDestination(isPresented: $navigateToPlayer) {
        WatchPlayerView()
          .environmentObject(audioManager)
      }
      .onAppear {
        homeViewModel.fetchTrending()
      }
    }
    .environmentObject(audioManager)
  }
}
