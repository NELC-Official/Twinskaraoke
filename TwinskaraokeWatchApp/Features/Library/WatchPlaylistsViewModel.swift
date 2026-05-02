import Combine
import Foundation

class WatchPlaylistsViewModel: ObservableObject {
  @Published var playlists: [Playlist] = []
  @Published var isLoading = false
  func fetchMusic() {
    guard
      let url = URL(
        string:
          "https://api.neurokaraoke.com/api/playlists?startIndex=0&pageSize=15&search=&sortBy=&sortDescending=False&isSetlist=True&year=0"
      )
    else { return }
    isLoading = true
    var request = URLRequest(url: url)
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    URLSession.shared.dataTask(with: request) { data, _, _ in
      if let data = data,
        let decodedData = try? JSONDecoder().decode([Playlist].self, from: data)
      {
        DispatchQueue.main.async {
          self.playlists = decodedData
          self.isLoading = false
        }
      } else {
        DispatchQueue.main.async {
          self.isLoading = false
        }
      }
    }.resume()
  }
}
