import Combine
import Foundation

class WatchHomeViewModel: ObservableObject {
  @Published var trending: [Song] = []
  @Published var isLoading = false
  func fetchTrending() {
    guard
      let url = URL(
        string: "https://api.neurokaraoke.com/api/explore/trendings?days=7&take=10")
    else { return }
    isLoading = true
    var request = URLRequest(url: url)
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    URLSession.shared.dataTask(with: request) { data, _, _ in
      if let data = data, let songs = try? JSONDecoder().decode([Song].self, from: data) {
        DispatchQueue.main.async {
          self.trending = songs
          self.isLoading = false
        }
      } else {
        DispatchQueue.main.async { self.isLoading = false }
      }
    }.resume()
  }
}
