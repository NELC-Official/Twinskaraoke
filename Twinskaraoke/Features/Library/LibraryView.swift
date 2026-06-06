import Combine
import SwiftUI

extension Playlist: Hashable {
  public static func == (lhs: Playlist, rhs: Playlist) -> Bool { lhs.id == rhs.id }
  public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
final class PlaylistSongCountStore: ObservableObject {
  static let shared = PlaylistSongCountStore()

  @Published private var resolvedCounts: [String: Int] = [:]
  private var loadingIDs: Set<String> = []

  func displayedCount(for playlist: Playlist) -> Int? {
    if let resolved = resolvedCounts[playlist.id], resolved > 0 {
      return resolved
    }
    let embeddedCount = playlist.songListDTOs?.count ?? 0
    if embeddedCount > 0 {
      return max(playlist.songCount, embeddedCount)
    }
    return playlist.songCount > 0 ? playlist.songCount : nil
  }

  func loadIfNeeded(for playlist: Playlist) {
    guard !playlist.isFavorites, !playlist.isPersonal else { return }
    guard playlist.songCount == 0 else { return }
    guard resolvedCounts[playlist.id] == nil else { return }
    guard !loadingIDs.contains(playlist.id) else { return }
    guard let url = URL(string: "\(StorageHost.api)/api/playlist/\(playlist.id)") else { return }

    loadingIDs.insert(playlist.id)
    var request = URLRequest(url: url)
    if let token = UserDefaults.standard.string(forKey: "nk.token"), !token.isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    GuestIdentity.applyIfNeeded(to: &request)

    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      let count = Self.resolveCount(from: data)
      DispatchQueue.main.async {
        guard let self else { return }
        self.loadingIDs.remove(playlist.id)
        if let count, count > 0 {
          self.resolvedCounts[playlist.id] = count
        }
      }
    }.resume()
  }

  nonisolated private static func resolveCount(from data: Data?) -> Int? {
    guard let data else { return nil }
    let decoder = JSONDecoder()
    if let playlist = try? decoder.decode(Playlist.self, from: data) {
      return max(playlist.songCount, playlist.songListDTOs?.count ?? 0)
    }
    if let songs = SongPayloadDecoder.decodeSongs(from: data) {
      return songs.count
    }
    return nil
  }
}

struct PlaylistSongCountLabel: View {
  let playlist: Playlist
  var fallbackText: String? = nil

  @ObservedObject private var countStore = PlaylistSongCountStore.shared

  private var labelText: String? {
    if let count = countStore.displayedCount(for: playlist) {
      return "\(count) songs"
    }
    return fallbackText
  }

  var body: some View {
    Group {
      if let labelText {
        Text(labelText)
      }
    }
    .task(id: playlist.id) {
      countStore.loadIfNeeded(for: playlist)
    }
  }
}

struct LibraryView: View {
  @StateObject var viewModel = PlaylistsViewModel()
  @ObservedObject private var savedStore = SavedPlaylistsStore.shared
  @ObservedObject private var addedTracker = RecentlyAddedTracker.shared
  @ObservedObject private var favorites = FavoritesManager.shared
  @State private var path = NavigationPath()
  let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
  var body: some View {
    let recents = viewModel.recentlyAddedPlaylists(saved: savedStore.playlists)
    NavigationStack(path: $path) {
      List {
        Section {
          NavigationLink {
            PlaylistsGridScreen(viewModel: viewModel)
          } label: {
            LibraryRow(icon: "music.note.list", color: .appAccent, title: "Playlists")
          }
          NavigationLink {
            ArtistsView()
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
            VideoGalleryView()
          } label: {
            LibraryRow(icon: "play.rectangle", color: .appAccent, title: "Video Gallery")
          }
          NavigationLink {
            ArtGalleryView()
          } label: {
            LibraryRow(icon: "paintpalette", color: .appAccent, title: "Art Gallery")
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
            LibraryRow(icon: "arrow.down.circle", color: .appAccent, title: "Downloaded")
          }
          NavigationLink {
            RandomSongsView()
          } label: {
            LibraryRow(icon: "shuffle", color: .appAccent, title: "Random Songs")
          }
        }
        if !recents.isEmpty {
          Section {
            RecentlyAddedSection(playlists: recents) { playlist in
              path.append(playlist)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
          }
          .listSectionSpacing(8)
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .musicScreenBackground()
      .navigationTitle("Library")
      .navigationBarTitleDisplayMode(.large)
      .refreshable {
        favorites.loadIfNeeded()
        viewModel.fetchPlaylists()
        viewModel.fetchFavoriteSongs()
      }
      .navigationDestination(for: Playlist.self) { playlist in
        PlaylistDetailView(playlist: playlist)
      }
      .onAppear {
        favorites.loadIfNeeded()
        viewModel.fetchPlaylists()
        viewModel.fetchFavoriteSongs()
      }
      .onChange(of: favorites.favoriteIDs) { _, _ in
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
        .font(.system(size: 22, weight: .medium))
        .foregroundColor(color)
        .frame(width: 30)
      Text(title)
        .font(.system(size: 19, weight: .regular))
      Spacer()
    }
    .padding(.vertical, 7)
  }
}

struct PlaylistListRow: View {
  let playlist: Playlist
  var body: some View {
    HStack(spacing: 12) {
      PlaylistArtwork(playlist: playlist, cornerRadius: 6)
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(playlist.name)
          .font(.system(size: 15, weight: .medium))
          .lineLimit(1)
        PlaylistSongCountLabel(playlist: playlist, fallbackText: "Playlist")
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
  @ObservedObject var savedStore: SavedPlaylistsStore = .shared
  @ObservedObject private var userManager = UserPlaylistsManager.shared
  @ObservedObject private var favorites = FavoritesManager.shared
  @State private var showCreateSheet = false
  let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
  private var isLoggedIn: Bool {
    UserDefaults.standard.string(forKey: "nk.token") != nil
  }
  private var combinedPlaylists: [Playlist] {
    let userConverted = userManager.playlists.map { $0.asPlaylist() }
    let all = viewModel.allPlaylists(saved: savedStore.playlists)
    let existingIDs = Set(all.map { $0.id })
    let uniqueUser = userConverted.filter { !existingIDs.contains($0.id) }
    return uniqueUser + all
  }
  var body: some View {
    let all = combinedPlaylists
    ScrollView {
      Group {
        if viewModel.isLoading && userManager.isLoading && all.isEmpty {
          PlaylistsSkeletonView(cols: cols)
        } else if all.isEmpty {
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
            ForEach(all) { playlist in
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
    .toolbar {
      if isLoggedIn {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showCreateSheet = true
          } label: {
            Image(systemName: "plus")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.appAccent)
          }
        }
      }
    }
    .task { userManager.loadIfNeeded() }
    .onChange(of: favorites.favoriteIDs) { _, _ in
      viewModel.fetchFavoriteSongs()
    }
    .sheet(isPresented: $showCreateSheet) {
      CreatePlaylistSheet()
    }
  }
}

struct PlaylistGridCell: View {
  let playlist: Playlist
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      PlaylistArtwork(playlist: playlist, cornerRadius: AM.Radius.card)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AM.Radius.card, style: .continuous))
        .amShadow(AM.Shadow.card)
      Text(playlist.name)
        .font(AM.Font.tileTitle)
        .foregroundColor(.primary)
        .lineLimit(1)
      PlaylistSongCountLabel(playlist: playlist, fallbackText: "Playlist")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct RecentlyAddedSection: View {
  let playlists: [Playlist]
  let onSelect: (Playlist) -> Void
  private let cols = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14),
  ]
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      AMSectionHeader("Recently Added")
      LazyVGrid(columns: cols, spacing: 22) {
        ForEach(playlists) { playlist in
          Button {
            onSelect(playlist)
          } label: {
            RecentlyAddedTile(playlist: playlist)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 16)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct RecentlyAddedTile: View {
  let playlist: Playlist
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      PlaylistArtwork(playlist: playlist, cornerRadius: 6)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AM.Radius.card, style: .continuous))
        .amShadow(AM.Shadow.card)
      VStack(alignment: .leading, spacing: 2) {
        Text(playlist.name)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)
          .lineLimit(1)
        PlaylistSongCountLabel(playlist: playlist, fallbackText: "Playlist")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
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
