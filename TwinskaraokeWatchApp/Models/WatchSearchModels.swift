import Foundation

struct SearchSongItem: Codable, Identifiable {
  let id: String
  let title: String
  let duration: Int
  let absolutePath: String?
  let originalArtists: [String]?
  let coverArtists: [String]?
  let coverArt: SearchMedia?
  let cloudflareId: String?
  var imageURL: URL? {
    if let cfId = cloudflareId, !cfId.isEmpty {
      return URL(string: "https://images.neurokaraoke.com/\(cfId)/public")
    }
    guard let path = coverArt?.absolutePath else { return nil }
    return URL(string: "https://images.neurokaraoke.com" + path + "/quality=95")
  }
  var originalArtistDisplay: String {
    originalArtists?.joined(separator: ", ") ?? ""
  }
  func toSong() -> Song? {
    guard let absPath = absolutePath else { return nil }
    return Song(
      id: id, title: title, duration: duration, absolutePath: absPath,
      coverArt: coverArt.map { SongMedia(absolutePath: $0.absolutePath) },
      coverArtists: coverArtists, originalArtists: originalArtists,
      cloudflareId: cloudflareId)
  }
}

struct SearchMedia: Codable {
  let absolutePath: String
}

struct SearchResponseRoot: Codable {
  let items: [SearchSongItem]
}
