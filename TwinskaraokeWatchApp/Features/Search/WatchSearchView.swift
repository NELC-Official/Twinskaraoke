import SwiftUI

struct WatchSearchView: View {
  @StateObject var viewModel = WatchSearchViewModel()
  @EnvironmentObject var audioManager: WatchAudioManager
  @State private var showPlayer = false
  var body: some View {
    VStack(spacing: 0) {
      TextField("Search...", text: $viewModel.searchText)
        .padding(8)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 4)
      List {
        if viewModel.isLoading {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .listRowBackground(Color.clear)
        } else {
          ForEach(viewModel.results) { item in
            Button {
              if let song = item.toSong() {
                let allSongs = viewModel.results.compactMap { $0.toSong() }
                audioManager.play(song: song, context: allSongs)
                showPlayer = true
              }
            } label: {
              HStack(spacing: 12) {
                if let url = item.imageURL {
                  AsyncImage(url: url) { image in
                    image.resizable()
                      .scaledToFill()
                  } placeholder: {
                    Color.secondary.opacity(0.15)
                  }
                  .frame(width: 40, height: 40)
                  .cornerRadius(6)
                } else {
                  Image(systemName: "music.note")
                    .frame(width: 40, height: 40)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                }
                VStack(alignment: .leading, spacing: 1) {
                  Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                  Text(item.originalArtistDisplay)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
              }
              .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .navigationTitle("Search")
    .navigationDestination(isPresented: $showPlayer) {
      WatchPlayerView()
        .environmentObject(audioManager)
    }
  }
}
