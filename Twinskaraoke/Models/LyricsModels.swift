import Foundation

nonisolated struct LyricLine: Identifiable, Codable {
  let id = UUID()
  let time: TimeInterval
  let text: String
  let translatedText: String?

  enum CodingKeys: String, CodingKey {
    case time
    case text
    case translatedText
  }

  init(time: TimeInterval, text: String, translatedText: String? = nil) {
    self.time = time
    self.text = text
    self.translatedText = translatedText
  }

  func withTranslation(_ translatedText: String?) -> LyricLine {
    LyricLine(time: time, text: text, translatedText: translatedText)
  }
}

nonisolated struct RawLyricLine: Codable {
  let time: String
  let text: String
}

nonisolated enum TimeSpanParser {
  static func parse(_ raw: String) -> TimeInterval? {
    let parts = raw.split(separator: ":")
    guard parts.count == 3 else { return nil }
    guard let hours = Double(parts[0]),
      let minutes = Double(parts[1])
    else { return nil }
    let secParts = parts[2].split(separator: ".")
    guard let wholeSeconds = Double(secParts[0]) else { return nil }
    var fraction: Double = 0
    if secParts.count > 1 {
      fraction = Double("0." + secParts[1]) ?? 0
    }
    return hours * 3600 + minutes * 60 + wholeSeconds + fraction
  }
}
