import SwiftUI

struct AboutView: View {
  private var appVersion: String {
    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(v) (\(b))"
  }
  var body: some View {
    List {
      Section {
        VStack(spacing: 14) {
          Image(systemName: "music.note")
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 88, height: 88)
            .background(
              LinearGradient(
                colors: [Color.appAccent, Color.appAccent.opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
              )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.appAccent.opacity(0.35), radius: 18, y: 8)
          Text("TwinsKaraoke")
            .font(.title2.bold())
          Text("Version \(appVersion)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .listRowBackground(Color.clear)
        .listRowInsets(.init())
      }
      Section("About") {
        Text(
          "TwinsKaraoke is a karaoke-first music player with a built-in radio station, "
            + "vocal-removal sing mode, and DJ-style auto mix. Built with SwiftUI."
        )
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
      }
      Section("Resources") {
        Link(destination: URL(string: "https://radio.twinskaraoke.com")!) {
          AboutLinkRow(icon: "dot.radiowaves.left.and.right", color: .appAccent, title: "Radio Station")
        }
        Link(destination: URL(string: "https://api.neurokaraoke.com")!) {
          AboutLinkRow(icon: "server.rack", color: .blue, title: "API Service")
        }
      }
      Section("Legal") {
        NavigationLink {
          legalText("Privacy Policy", body: privacyBody)
        } label: {
          AboutLinkRow(icon: "hand.raised.fill", color: .gray, title: "Privacy Policy")
        }
        NavigationLink {
          legalText("Terms of Service", body: termsBody)
        } label: {
          AboutLinkRow(icon: "doc.text.fill", color: .gray, title: "Terms of Service")
        }
        NavigationLink {
          AcknowledgementsView()
        } label: {
          AboutLinkRow(icon: "heart.fill", color: .pink, title: "Acknowledgements")
        }
      }
      Section {
        Text("© 2026 TwinsKaraoke")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .listRowBackground(Color.clear)
      }
    }
    .navigationTitle("About")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func legalText(_ title: String, body: String) -> some View {
    ScrollView {
      Text(body)
        .font(.system(size: 14))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var privacyBody: String {
    """
    TwinsKaraoke stores your sign-in token, recently played playlists, and downloaded \
    audio entirely on this device. We do not sell or share your listening data with \
    third parties.

    Anonymous guest identifiers are sent to api.neurokaraoke.com when you browse the \
    catalog. When you sign in, your account token is sent to the same service to fetch \
    your favorites and personal settings.

    Audio cover art and song files are streamed from neurokaraoke.com. Live radio \
    metadata comes from radio.twinskaraoke.com.
    """
  }

  private var termsBody: String {
    """
    By using TwinsKaraoke you agree to use the service only for personal, \
    non-commercial enjoyment. The catalog is provided as-is. Songs and cover art \
    remain the property of their respective owners.

    Live radio playback is offered on a best-effort basis and may be unavailable due \
    to network conditions or maintenance.

    Auto Mix and Vocal Removal are signal-processing conveniences and may not work \
    cleanly on every track. Audio output is not modified for downloads.
    """
  }
}

private struct AboutLinkRow: View {
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

private struct AcknowledgementsView: View {
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
    .navigationTitle("Acknowledgements")
    .navigationBarTitleDisplayMode(.inline)
  }
}
