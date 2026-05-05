import Combine
import Foundation

class HomeViewModel: ObservableObject {
  @Published var trending: [Song] = []
  @Published var suggestions: [Song] = []
  @Published var recentPlaylists: [Playlist] = []
  @Published var isLoading = false
  private var hasLoaded = false
  func fetchHomeData(force: Bool = false) {
    if hasLoaded && !force { return }
    hasLoaded = true
    isLoading = true
    let group = DispatchGroup()
    group.enter()
    fetchData(urlString: "https://api.neurokaraoke.com/api/explore/trendings?days=7&take=20") {
      [weak self] (response: [Song]?) in
      if let response { DispatchQueue.main.async { self?.trending = response } }
      group.leave()
    }
    group.enter()
    fetchData(urlString: "https://api.neurokaraoke.com/api/user/suggestions?take=20") {
      [weak self] (response: [Song]?) in
      if let response { DispatchQueue.main.async { self?.suggestions = response } }
      group.leave()
    }
    group.enter()
    fetchData(
      urlString:
        "https://api.neurokaraoke.com/api/playlists?startIndex=0&pageSize=12&search=&sortBy=&sortDescending=True&isSetlist=True&year=0"
    ) { [weak self] (response: [Playlist]?) in
      if let response { DispatchQueue.main.async { self?.recentPlaylists = response } }
      group.leave()
    }
    group.notify(queue: .main) { [weak self] in self?.isLoading = false }
  }
  private func fetchData<T: Codable>(urlString: String, completion: @escaping (T?) -> Void) {
    guard let url = URL(string: urlString) else {
      completion(nil)
      return
    }
    var request = URLRequest(url: url)
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    URLSession.shared.dataTask(with: request) { data, _, _ in
      if let data, let decoded = try? JSONDecoder().decode(T.self, from: data) {
        completion(decoded)
      } else {
        completion(nil)
      }
    }.resume()
  }
}
