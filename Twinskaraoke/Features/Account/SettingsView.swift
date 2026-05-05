import SwiftUI

struct SettingsView: View {
  @StateObject private var audioManager = AudioPlayerManager.shared
  @AppStorage("nk.streamingQuality") private var streamingQuality: String = "high"
  @AppStorage("nk.downloadOnPlay") private var downloadOnPlay: Bool = false
  @AppStorage("nk.respectReducedMotion") private var respectReducedMotion: Bool = true
  var body: some View {
    List {
      Section {
        Toggle("Auto Mix", isOn: $audioManager.autoMixEnabled)
          .tint(.appAccent)
        Toggle("Crossfade", isOn: $audioManager.crossfadeEnabled)
          .tint(.appAccent)
        if audioManager.crossfadeEnabled {
          CrossfadeDurationRow(
            seconds: Binding(
              get: { audioManager.crossfadeSeconds },
              set: { audioManager.crossfadeSeconds = $0 }
            )
          )
        }
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
      } header: {
        Text("Playback")
      } footer: {
        Text("Auto Mix hands the next track off seamlessly with no dead air. Crossfade overlaps and fades between tracks; choose a shorter duration to keep the rhythm tight, or a longer one for a gentler, DJ-style transition.")
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

private struct CrossfadeDurationRow: View {
  @Binding var seconds: Double
  private let range: ClosedRange<Double> = 1...15
  private var displayLabel: String {
    let s = Int(seconds.rounded())
    return "\(s) Second\(s == 1 ? "" : "s")"
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Duration")
        Spacer()
        Text(displayLabel)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      Slider(
        value: Binding(
          get: { seconds },
          set: { seconds = $0.rounded() }
        ),
        in: range,
        step: 1
      ) {
        Text("Crossfade Duration")
      } minimumValueLabel: {
        Text("1s")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } maximumValueLabel: {
        Text("15s")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .tint(.appAccent)
    }
    .padding(.vertical, 2)
  }
}
