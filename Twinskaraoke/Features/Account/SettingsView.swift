import SwiftUI

struct SettingsView: View {
  @StateObject private var audioManager = AudioPlayerManager.shared
  @AppStorage("nk.streamingQuality") private var streamingQuality: String = "high"
  @AppStorage("nk.downloadOnPlay") private var downloadOnPlay: Bool = false
  @AppStorage("nk.respectReducedMotion") private var respectReducedMotion: Bool = true
  var body: some View {
    List {
      Section("Playback") {
        Toggle("Auto Mix", isOn: $audioManager.autoMixEnabled)
          .tint(.appAccent)
        Toggle("Autoplay Similar Songs", isOn: Binding(
          get: { audioManager.autoplayEnabled },
          set: { _ in audioManager.toggleAutoplay() }
        ))
        .tint(.appAccent)
        Picker("Audio Quality", selection: $streamingQuality) {
          Text("High Efficiency").tag("low")
          Text("High Quality").tag("medium")
          Text("Lossless").tag("high")
        }
      }
      Section {
        Toggle("Auto-Download Played Songs", isOn: $downloadOnPlay)
          .tint(.appAccent)
      } header: {
        Text("Downloads")
      } footer: {
        Text("When enabled, songs you play are saved for offline listening.")
      }
      Section("Karaoke") {
        Toggle("Vocal Removal", isOn: $audioManager.karaokeMode)
          .tint(.appAccent)
        if audioManager.karaokeMode {
          HStack {
            Text("Strength")
            Spacer()
            Text(strengthLabel)
              .foregroundStyle(.secondary)
          }
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(Color.primary.opacity(0.15))
              Capsule()
                .fill(Color.appAccent)
                .frame(width: max(8, geo.size.width * CGFloat(audioManager.karaokeStrength)))
            }
            .frame(height: 6)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  let v = max(0, min(1, value.location.x / geo.size.width))
                  audioManager.karaokeStrength = Float(v)
                }
            )
          }
          .frame(height: 28)
        }
      }
      Section("Appearance") {
        Toggle("Respect Reduce Motion", isOn: $respectReducedMotion)
          .tint(.appAccent)
      }
      Section {
        Button(role: .destructive) {
          DownloadManager.shared.removeAll()
        } label: {
          Text("Remove All Downloads")
        }
        Button(role: .destructive) {
          RecentlyPlayedStore.shared.reset()
        } label: {
          Text("Clear Recently Played")
        }
      } header: {
        Text("Storage")
      }
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
  }
  private var strengthLabel: String {
    let v = audioManager.karaokeStrength
    if v < 0.15 { return "Almost off" }
    if v < 0.45 { return "Light" }
    if v < 0.75 { return "Medium" }
    if v < 0.95 { return "Strong" }
    return "Maximum"
  }
}
