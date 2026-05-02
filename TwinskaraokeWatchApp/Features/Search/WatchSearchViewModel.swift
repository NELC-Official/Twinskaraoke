import Combine
import Foundation

class WatchSearchViewModel: ObservableObject {
  @Published var results: [SearchSongItem] = []
  @Published var isLoading = false
  @Published var searchText = ""
  private var cancellables = Set<AnyCancellable>()
  init() {
    $searchText
      .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
      .removeDuplicates()
      .sink { [weak self] text in
        if !text.isEmpty {
          self?.performSearch(query: text)
        } else {
          self?.results = []
        }
      }
      .store(in: &cancellables)
  }
  func performSearch(query: String) {
    guard let url = URL(string: "https://api.neurokaraoke.com/api/songs") else { return }
    isLoading = true
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    let body: [String: Any] = [
      "page": 1,
      "pageSize": 20,
      "search": query,
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: request) { data, _, _ in
      guard let data = data else {
        DispatchQueue.main.async { self.isLoading = false }
        return
      }
      do {
        let decoded = try JSONDecoder().decode(SearchResponseRoot.self, from: data)
        DispatchQueue.main.async {
          self.results = decoded.items
          self.isLoading = false
        }
      } catch {
        DispatchQueue.main.async { self.isLoading = false }
      }
    }.resume()
  }
}
