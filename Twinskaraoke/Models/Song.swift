import Foundation

struct Song: Codable, Identifiable, Equatable {
  let id: String
  let title: String
  let duration: Int
  let absolutePath: String?
  let cloudflareID: String?
  let coverArt: Media?
  let originalArtists: [String]?
  let coverArtists: [String]?
  enum CodingKeys: String, CodingKey {
    case id, title, duration, absolutePath, coverArt, originalArtists, coverArtists
    case cloudflareID = "cloudflareId"
  }
  var imageURL: URL? {
    if let identifier = cloudflareID {
      return URL(string: "https://images.neurokaraoke.com/\(identifier)/public")
    }
    guard let path = coverArt?.absolutePath else { return nil }
    return URL(string: "https://images.neurokaraoke.com" + path + "/quality=95")
  }
  var audioURL: URL? {
    guard let path = absolutePath else { return nil }
    let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return URL(string: "https://storage.neurokaraoke.com/\(cleanPath)")
  }
  var displayTitle: String {
    let artists = originalArtists?.joined(separator: ", ") ?? ""
    return artists.isEmpty ? title : "\(title) - \(artists)"
  }
  var displayCoverArtist: String {
    coverArtists?.joined(separator: ", ") ?? ""
  }
  /// Joined artist string with a stable fallback when no artist is available.
  /// Every track in this catalog is a cover, so the cover artist is appended
  /// when present (e.g. "Adele · Cover by Jane Doe").
  var displayArtist: String {
    let original = originalArtists?.filter { !$0.isEmpty }.joined(separator: ", ") ?? ""
    let cover = coverArtists?.filter { !$0.isEmpty }.joined(separator: ", ") ?? ""
    switch (original.isEmpty, cover.isEmpty) {
    case (false, false): return "\(original) · Cover by \(cover)"
    case (false, true):  return original
    case (true, false):  return "Cover by \(cover)"
    case (true, true):   return "Unknown Artist"
    }
  }
  /// `m:ss` formatted duration, blank for unknown lengths (e.g. live radio).
  var durationText: String {
    guard duration > 0 else { return "" }
    let m = duration / 60
    let s = duration % 60
    return String(format: "%d:%02d", m, s)
  }
  static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
}

struct Playlist: Codable, Identifiable {
  let id: String
  let name: String
  let songCount: Int
  let mosaicMedia: [Media]?
  let songListDTOs: [Song]?
  var imageURL: URL? {
    guard let path = mosaicMedia?.first?.absolutePath else { return nil }
    return URL(string: "https://images.neurokaraoke.com" + path + "/quality=95")
  }
}

struct Media: Codable {
  let absolutePath: String
}

struct SearchResponse: Codable {
  let items: [Song]
}
