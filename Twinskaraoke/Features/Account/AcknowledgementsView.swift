import SwiftUI

struct AcknowledgementsView: View {
  private struct Credit: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let url: URL?
  }
  private let credits: [Credit] = [
    Credit(
      name: "SDWebImageSwiftUI",
      detail: "MIT License",
      url: URL(string: "https://github.com/SDWebImage/SDWebImageSwiftUI")
    ),
    Credit(
      name: "SDWebImage",
      detail: "MIT License",
      url: URL(string: "https://github.com/SDWebImage/SDWebImage")
    ),
    Credit(
      name: "SF Symbols",
      detail: "© Apple Inc.",
      url: URL(string: "https://developer.apple.com/sf-symbols/")
    ),
  ]
  var body: some View {
    List(credits) { credit in
      VStack(alignment: .leading, spacing: 4) {
        Text(credit.name)
          .font(.system(size: 15, weight: .semibold))
        Text(credit.detail)
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
        if let url = credit.url {
          Link(url.absoluteString, destination: url)
            .font(.system(size: 12))
            .lineLimit(1)
        }
      }
      .padding(.vertical, 2)
    }
    .navigationTitle("Open Source Licenses")
    .navigationBarTitleDisplayMode(.inline)
  }
}
