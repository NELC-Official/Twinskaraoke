import Combine
import Foundation

class WatchPlaylistDetailViewModel: ObservableObject {
  @Published var songs: [Song] = []
  @Published var isLoading = false
  let playlistID: String
  init(playlistID: String) {
    self.playlistID = playlistID
  }
  func fetchSongs() {
    guard let url = URL(string: "https://api.neurokaraoke.com/api/playlist/\(playlistID)") else {
      return
    }
    isLoading = true
    var request = URLRequest(url: url)
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    URLSession.shared.dataTask(with: request) { data, _, _ in
      if let data = data,
        let decodedData = try? JSONDecoder().decode(PlaylistDetail.self, from: data)
      {
        DispatchQueue.main.async {
          self.songs = decodedData.songListDTOs
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
