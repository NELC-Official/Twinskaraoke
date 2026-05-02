import Combine
import Foundation

class PlaylistsViewModel: ObservableObject {
  @Published var playlists: [Playlist] = []
  @Published var favoriteSongs: [Song] = []
  @Published var isLoading = false
  func fetchPlaylists() {
    guard
      let url = URL(
        string:
          "https://api.neurokaraoke.com/api/playlists?startIndex=0&pageSize=25&search=&sortBy=&sortDescending=False&isSetlist=False&year=0"
      )
    else { return }
    isLoading = true
    var request = URLRequest(url: url)
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      if let data, let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
        DispatchQueue.main.async {
          self?.playlists = decoded
          self?.isLoading = false
        }
      } else {
        DispatchQueue.main.async { self?.isLoading = false }
      }
    }.resume()
  }
  func fetchFavoriteSongs() {
    guard let url = URL(string: "https://api.neurokaraoke.com/api/favorites/type?type=0") else {
      return
    }
    var request = URLRequest(url: url)
    if let token = UserDefaults.standard.string(forKey: "nk.token") {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      guard let data else { return }
      if let decoded = try? JSONDecoder().decode([Song].self, from: data) {
        DispatchQueue.main.async { self?.favoriteSongs = decoded }
        return
      }
      if let wrapped = try? JSONDecoder().decode([FavoriteSongEnvelope].self, from: data) {
        DispatchQueue.main.async {
          self?.favoriteSongs = wrapped.compactMap { $0.song }
        }
      }
    }.resume()
  }
}

private struct FavoriteSongEnvelope: Decodable {
  let song: Song?

  enum CodingKeys: String, CodingKey { case song, songData, songDTO }
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let decoded = try? container.decode(Song.self, forKey: .song) {
      song = decoded
    } else if let decoded = try? container.decode(Song.self, forKey: .songData) {
      song = decoded
    } else if let decoded = try? container.decode(Song.self, forKey: .songDTO) {
      song = decoded
    } else {
      song = nil
    }
  }
}
