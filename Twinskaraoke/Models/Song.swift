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
      return URL(string: "\(StorageHost.images)/\(identifier)/public")
    }
    guard let path = coverArt?.absolutePath else { return neuroFallbackImageURL }
    return URL(string: StorageHost.images + path + "/quality=95")
  }
  var hasOwnArtwork: Bool {
    cloudflareID != nil || coverArt?.absolutePath != nil
  }
  private static let neuroArtistNames: Set<String> = ["Neuro", "Neuro v1", "Neuro v2"]
  private var neuroFallbackImageURL: URL? {
    let artists = coverArtists ?? []
    let isNeuro = artists.contains { Self.neuroArtistNames.contains($0) }
    guard isNeuro else { return nil }
    return URL(string: "\(StorageHost.images)/WxURxyML82UkE7gY-PiBKw/277232b2-e00e-426b-ffb8-bb8664a73600/quality=95")
  }
  var audioURL: URL? {
    guard let path = absolutePath else { return nil }
    let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return URL(string: "\(StorageHost.base)/\(cleanPath)")
  }
  var displayTitle: String {
    let artists = originalArtists?.joined(separator: ", ") ?? ""
    return artists.isEmpty ? title : "\(title) - \(artists)"
  }
  var displayCoverArtist: String {
    coverArtists?.joined(separator: ", ") ?? ""
  }
  var displayArtist: String {
    let original = originalArtists?.filter { !$0.isEmpty }.joined(separator: ", ") ?? ""
    let cover = coverArtists?.filter { !$0.isEmpty }.joined(separator: ", ") ?? ""
    switch (original.isEmpty, cover.isEmpty) {
    case (false, false): return "\(original) · Cover by \(cover)"
    case (false, true): return original
    case (true, false): return "Cover by \(cover)"
    case (true, true):
      let apiProvidedArtists = originalArtists != nil || coverArtists != nil
      return apiProvidedArtists ? "Unknown Artist" : ""
    }
  }
  var hasArtistMetadata: Bool {
    let original = originalArtists?.filter { !$0.isEmpty } ?? []
    let cover = coverArtists?.filter { !$0.isEmpty } ?? []
    return !original.isEmpty || !cover.isEmpty
  }
  var durationText: String {
    guard duration > 0 else { return "" }
    let m = duration / 60
    let s = duration % 60
    return String(format: "%d:%02d", m, s)
  }
  static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
}

struct Playlist: Codable, Identifiable {
  static let favoritesID = "__favorites__"
  let id: String
  let name: String
  let songCount: Int
  let mosaicMedia: [Media]?
  let songListDTOs: [Song]?
  var imageURL: URL? {
    guard let path = mosaicMedia?.first?.absolutePath else { return nil }
    return URL(string: StorageHost.images + path + "/quality=95")
  }
  var isFavorites: Bool { id == Self.favoritesID }
}

struct Media: Codable {
  let absolutePath: String
}

struct SearchResponse: Codable {
  let items: [Song]
}
