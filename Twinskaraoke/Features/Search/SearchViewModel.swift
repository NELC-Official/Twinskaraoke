import Combine
import Foundation

class SearchViewModel: ObservableObject {
  @Published var results: [Song] = []
  @Published var searchText = ""
  @Published var isSearching = false
  private var cancellables = Set<AnyCancellable>()
  // Monotonic token bumped on every new query so stale completions can be
  // dropped instead of clobbering a more recent search.
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
    guard let url = URL(string: "https://api.neurokaraoke.com/api/songs") else { return }
    queryToken += 1
    let token = queryToken
    isSearching = true
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    request.httpBody = try? JSONSerialization.data(withJSONObject: [
      "page": 1, "pageSize": 30, "search": query,
    ])
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      if let data, let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) {
        DispatchQueue.main.async {
          guard let self, self.queryToken == token else { return }
          self.results = decoded.items
          self.isSearching = false
        }
      } else {
        DispatchQueue.main.async {
          guard let self, self.queryToken == token else { return }
          self.isSearching = false
        }
      }
    }.resume()
  }
}
