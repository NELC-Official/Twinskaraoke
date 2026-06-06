import Combine
import Foundation

#if canImport(UIKit)
  import UIKit
#endif

nonisolated struct GenreSummary: Decodable, Identifiable, Sendable {
  let id: String
  let name: String
  let songCount: Int

  enum CodingKeys: String, CodingKey { case id, name, songCount, count }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    if let v = try c.decodeIfPresent(Int.self, forKey: .songCount) {
      songCount = v
    } else {
      songCount = (try? c.decode(Int.self, forKey: .count)) ?? 0
    }
  }
}

nonisolated private struct GenreDetail: Decodable, Sendable {
  let id: String
  let name: String
  let songs: [Song]?
}

@MainActor
final class PublicPlaylistsViewModel: ObservableObject {
  @Published var playlists: [Playlist] = []
  @Published var isLoadingMore = false
  private var canLoadMore = true
  private var hasLoaded = false
  private let pageSize = 25

  func loadIfNeeded() {
    guard !hasLoaded else { return }
    hasLoaded = true
    fetchPage(startIndex: 0, replace: true)
  }

  func loadMoreIfNeeded(current: Playlist) {
    guard let idx = playlists.firstIndex(where: { $0.id == current.id }) else { return }
    if idx >= playlists.count - 4 && !isLoadingMore && canLoadMore {
      fetchPage(startIndex: playlists.count, replace: false)
    }
  }

  func urlForList(startIndex: Int, pageSize: Int) -> String {
    "\(StorageHost.api)/api/playlist/public?startIndex=\(startIndex)&pageSize=\(pageSize)&search=&sortBy=UpdatedAt&sortDescending=True"
  }

  private func fetchPage(startIndex: Int, replace: Bool) {
    let urlString = urlForList(startIndex: startIndex, pageSize: pageSize)
    guard let url = URL(string: urlString) else { return }
    if !replace { isLoadingMore = true }
    var request = URLRequest(url: url)
    GuestIdentity.applyIfNeeded(to: &request)
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let items = Self.decode(data: data)
        if replace {
          self.playlists = items
        } else {
          let existing = Set(self.playlists.map { $0.id })
          self.playlists += items.filter { !existing.contains($0.id) }
        }
        self.canLoadMore = items.count >= self.pageSize
        self.isLoadingMore = false
      }
    }.resume()
  }

  private static func decode(data: Data?) -> [Playlist] {
    guard let data else { return [] }
    let decoder = JSONDecoder()
    if let items = (try? decoder.decode(LossyArray<PlaylistListItem>.self, from: data))?.elements {
      return items.map { $0.asPlaylist() }
    }
    if let items = try? decoder.decode([PlaylistListItem].self, from: data) {
      return items.map { $0.asPlaylist() }
    }
    return []
  }
}

nonisolated private enum TopChartSection: Sendable {
  case songs
  case weeklyTrending
}

@MainActor
final class TopChartViewModel: ObservableObject {
  @Published var songs: [Song] = []
  @Published var weeklyTrending: [Song] = []

  func loadIfNeeded() {
    fetch(
      url: "\(StorageHost.api)/api/explore/trendings?days=all",
      target: .songs)
    fetch(
      url: "\(StorageHost.api)/api/explore/trendings?days=7&take=20",
      target: .weeklyTrending)
  }

  private func fetch(url: String, target: TopChartSection) {
    guard let u = URL(string: url) else { return }
    var request = URLRequest(url: u)
    GuestIdentity.applyIfNeeded(to: &request)
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      Task { @MainActor [weak self, data, target] in
        self?.applyTopChartResponse(data, to: target)
      }
    }.resume()
  }

  private func applyTopChartResponse(_ data: Data?, to target: TopChartSection) {
    guard let data, let list = try? JSONDecoder().decode([Song].self, from: data) else {
      return
    }

    switch target {
    case .songs:
      songs = list
    case .weeklyTrending:
      weeklyTrending = list
    }
  }
}

@MainActor
final class GenresViewModel: ObservableObject {
  @Published var genres: [GenreSummary] = []
  @Published var artworkURLs: [String: URL] = [:]
  @Published var firstSongs: [String: Song] = [:]
  @Published var allSongs: [String: [Song]] = [:]
  @Published var isLoadingMore = false
  @Published var canLoadMore = true
  private var page = 0
  private let pageSize = 50
  private var genreDetailOrder: [String] = []
  private let maxCachedGenreDetails = 30

  init() {
    #if canImport(UIKit)
      NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification,
        object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.clearCachedGenreDetails()
        }
      }
    #endif
  }

  func loadIfNeeded() {
    fetchPage(0, replace: true)
  }

  func loadMoreIfNeeded(current: GenreSummary) {
    guard let idx = genres.firstIndex(where: { $0.id == current.id }) else { return }
    if idx >= genres.count - 6 && !isLoadingMore && canLoadMore {
      fetchPage(page, replace: false)
    }
  }

  private func clearCachedGenreDetails() {
    allSongs.removeAll()
    firstSongs.removeAll()
    genreDetailOrder.removeAll()
  }

  private func fetchPage(_ page: Int, replace: Bool) {
    guard
      let url = URL(
        string:
          "\(StorageHost.api)/api/filters/genres?page=\(page)&pageSize=\(pageSize)")
    else { return }
    isLoadingMore = !replace
    var request = URLRequest(url: url)
    GuestIdentity.applyIfNeeded(to: &request)
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      Task { @MainActor [weak self, data, page, replace] in
        self?.applyGenrePageResponse(data, page: page, replace: replace)
      }
    }.resume()
  }

  private func applyGenrePageResponse(_ data: Data?, page: Int, replace: Bool) {
    defer { isLoadingMore = false }

    guard let data, let list = try? JSONDecoder().decode([GenreSummary].self, from: data) else {
      canLoadMore = false
      return
    }

    let filtered = list.filter { $0.songCount > 0 }
    if replace {
      genres = filtered
    } else {
      let existing = Set(genres.map { $0.id })
      genres += filtered.filter { !existing.contains($0.id) }
    }
    canLoadMore = list.count == pageSize
    self.page = page + 1
    for genre in filtered {
      fetchDetail(for: genre)
    }
  }

  private static let neuroFallbackURL: URL? = FallbackArtProvider.shared.randomURL

  private func fetchDetail(for genre: GenreSummary) {
    if allSongs[genre.id] != nil { return }
    guard let url = URL(string: "\(StorageHost.api)/api/genres/\(genre.id)") else {
      return
    }
    var request = URLRequest(url: url)
    GuestIdentity.applyIfNeeded(to: &request)
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      Task { @MainActor [weak self, data, genre] in
        self?.applyGenreDetailResponse(data, for: genre)
      }
    }.resume()
  }

  private func applyGenreDetailResponse(_ data: Data?, for genre: GenreSummary) {
    guard let data,
      let detail = try? JSONDecoder().decode(GenreDetail.self, from: data),
      let songs = detail.songs
    else {
      return
    }

    allSongs[genre.id] = songs
    if let first = songs.first {
      firstSongs[genre.id] = first
    }
    let artURL = songs.first(where: { $0.hasOwnArtwork })?.imageURL ?? Self.neuroFallbackURL
    artworkURLs[genre.id] = artURL
    genreDetailOrder.removeAll { $0 == genre.id }
    genreDetailOrder.append(genre.id)
    while genreDetailOrder.count > maxCachedGenreDetails {
      let oldest = genreDetailOrder.removeFirst()
      allSongs.removeValue(forKey: oldest)
      firstSongs.removeValue(forKey: oldest)
    }
  }
}

@MainActor
final class SearchViewModel: ObservableObject {
  @Published var results: [Song] = []
  @Published var searchText = ""
  @Published var isSearching = false
  private var cancellables = Set<AnyCancellable>()
  private var queryToken: Int = 0

  init() {
    $searchText
      .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
      .removeDuplicates()
      .sink { [weak self] query in
        if !query.isEmpty { self?.search(query) } else { self?.results = [] }
      }
      .store(in: &cancellables)
  }

  func search(_ query: String) {
    guard let url = URL(string: "\(StorageHost.api)/api/songs") else { return }
    queryToken += 1
    let token = queryToken
    isSearching = true
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    GuestIdentity.applyIfNeeded(to: &request)
    request.httpBody = try? JSONSerialization.data(withJSONObject: [
      "page": 1, "pageSize": 30, "search": query,
    ])
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      Task { @MainActor [weak self, data, token] in
        self?.applySearchResponse(data, token: token)
      }
    }.resume()
  }

  private func applySearchResponse(_ data: Data?, token: Int) {
    guard queryToken == token else { return }
    defer { isSearching = false }

    guard let data, let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
      return
    }

    results = decoded.items
  }
}
