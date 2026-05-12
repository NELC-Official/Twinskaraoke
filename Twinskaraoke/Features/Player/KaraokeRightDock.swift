import SwiftUI

struct KaraokeRightDock: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  @Binding var showKaraokeControls: Bool
  var body: some View {
    VStack(spacing: 12) {
      if showKaraokeControls && audioManager.karaokeMode {
        karaokeVerticalSlider
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      karaokeMicButton
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showKaraokeControls)
    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: audioManager.karaokeMode)
  }
  private var karaokeMicButton: some View {
    Button {
      if audioManager.karaokeMode {
        audioManager.karaokeMode = false
        showKaraokeControls = false
      } else {
        audioManager.karaokeMode = true
        showKaraokeControls = true
      }
    } label: {
      Image(systemName: audioManager.karaokeMode ? "mic.fill" : "mic")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(audioManager.karaokeMode ? .appAccent : .primary.opacity(0.85))
        .frame(width: 36, height: 36)
        .background(
          Circle()
            .fill(.ultraThinMaterial)
        )
        .overlay(
          Circle()
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }
    .buttonStyle(PressableButtonStyle(scale: 0.9, dim: 0.7))
  }
  private var karaokeVerticalSlider: some View {
    VStack(spacing: 8) {
      Image(systemName: "person.slash")
        .font(.system(size: 11))
        .foregroundColor(.secondary)
      VerticalKaraokeLevel(
        value: Binding(
          get: { Double(audioManager.aiVocalStrength) },
          set: { audioManager.aiVocalStrength = Float($0) }
        ),
        enabled: audioManager.karaokeMode,
        onSet: { _ in
          if !audioManager.karaokeMode { audioManager.karaokeMode = true }
        }
      )
      .frame(width: 28, height: 180)
      Image(systemName: "person.wave.2")
        .font(.system(size: 11))
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 8)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(.ultraThinMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
    )
    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
  }
}
