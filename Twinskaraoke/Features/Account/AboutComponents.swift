import SwiftUI

struct AboutLinkRow: View {
  let icon: String
  let color: Color
  let title: String
  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      Text(title)
      Spacer()
    }
  }
}

struct LinkifiedText: View {
  let text: String
  var body: some View {
    let parts = LinkifiedText.split(text)
    parts.reduce(Text("")) { acc, part in
      switch part {
      case .text(let s):
        return acc + Text(s)
      case .url(let s, let url):
        return acc
          + Text(
            AttributedString(
              s,
              attributes: AttributeContainer([
                .link: url,
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
              ])))
      }
    }
  }

  private enum Part {
    case text(String)
    case url(String, URL)
  }
  private static let detector: NSDataDetector? = {
    try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
  }()
  private static func split(_ string: String) -> [Part] {
    guard let detector else { return [.text(string)] }
    let nsRange = NSRange(string.startIndex..<string.endIndex, in: string)
    let matches = detector.matches(in: string, options: [], range: nsRange)
    if matches.isEmpty { return [.text(string)] }
    var parts: [Part] = []
    var cursor = string.startIndex
    for match in matches {
      guard let range = Range(match.range, in: string), let url = match.url else { continue }
      if cursor < range.lowerBound {
        parts.append(.text(String(string[cursor..<range.lowerBound])))
      }
      parts.append(.url(String(string[range]), url))
      cursor = range.upperBound
    }
    if cursor < string.endIndex {
      parts.append(.text(String(string[cursor..<string.endIndex])))
    }
    return parts
  }
}
