import Foundation

struct Playlist: Codable, Identifiable {
  let id: String
  let name: String
  let songCount: Int
  let mosaicMedia: [Media]?
  var imageURL: URL? {
    guard let path = mosaicMedia?.first?.absolutePath else { return nil }
    return URL(string: "https://images.neurokaraoke.com" + path + "/quality=95")
  }
}

struct Media: Codable {
  let absolutePath: String
}
