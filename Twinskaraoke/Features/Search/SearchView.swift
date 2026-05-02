import SwiftUI

struct SearchView: View {
  @StateObject var viewModel = SearchViewModel()
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    NavigationStack {
      Group {
        if viewModel.isSearching {
          List {
            ForEach(0..<8, id: \.self) { _ in
              SearchRowSkeleton()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
          }
          .listStyle(.plain)
          .transition(.opacity)
        } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 42))
              .foregroundColor(.secondary)
            Text("No results for \"\(viewModel.searchText)\"")
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .transition(.opacity)
        } else if viewModel.results.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 42))
              .foregroundColor(Color.secondary.opacity(0.5))
            Text("Search for songs or artists")
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .transition(.opacity)
        } else {
          List(viewModel.results) { song in
            Button {
              audioManager.play(song: song, context: viewModel.results)
            } label: {
              SearchResultRow(song: song)
            }
            .buttonStyle(PressableButtonStyle())
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
          }
          .listStyle(.plain)
          .transition(.opacity)
        }
      }
      .animation(.easeInOut(duration: 0.3), value: "\(viewModel.isSearching)-\(viewModel.results.count)-\(viewModel.searchText.isEmpty)")
      .navigationTitle("Search")
      .searchable(text: $viewModel.searchText, prompt: "Songs, artists…")
    }
  }
}

struct SearchResultRow: View {
  let song: Song
  var body: some View {
    SongRow(song: song, size: .regular)
  }
}

struct SearchRowSkeleton: View {
  var body: some View {
    SongRowSkeleton(size: .regular)
  }
}
