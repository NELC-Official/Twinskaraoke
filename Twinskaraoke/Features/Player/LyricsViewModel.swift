import Combine
import Foundation

class LyricsViewModel: ObservableObject {
  @Published var lyrics: [LyricLine] = []
  @Published var isLoading = false
  private(set) var loadedSongID: String?
  func adopt(songID: String, lyrics: [LyricLine]) {
    loadedSongID = songID
    self.lyrics = lyrics
    isLoading = false
  }
  func fetch(songID: String) {
    guard songID != loadedSongID else { return }
    loadedSongID = songID
    lyrics = []
    isLoading = true
    guard
      let url = URL(
        string: "https://api.neurokaraoke.com/api/songs/\(songID)/lyrics")
    else {
      isLoading = false
      return
    }
    var request = URLRequest(url: url)
    request.setValue(GuestIdentity.current, forHTTPHeaderField: "x-guest-id")
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      guard let data = data else {
        DispatchQueue.main.async {
          guard let self, self.loadedSongID == songID else { return }
          self.isLoading = false
        }
        return
      }
      do {
        let raw = try JSONDecoder().decode([RawLyricLine].self, from: data)
        let parsed = raw.compactMap { line -> LyricLine? in
          guard let time = TimeSpanParser.parse(line.time) else { return nil }
          return LyricLine(time: time, text: line.text)
        }
        DispatchQueue.main.async {
          guard let self, self.loadedSongID == songID else { return }
          self.lyrics = parsed
          self.isLoading = false
        }
      } catch {
        DispatchQueue.main.async {
          guard let self, self.loadedSongID == songID else { return }
          self.isLoading = false
        }
      }
    }.resume()
  }
}
