import SwiftUI
#if canImport(UIKit)
  import UIKit
#endif

struct PlayerBottomToolbar: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  @Binding var showingQueue: Bool
  let song: Song
  let onLyricsToggle: () -> Void
  let showLyrics: Bool
  var body: some View {
    HStack(spacing: audioManager.isRadioMode ? 56 : 0) {
      if !audioManager.isRadioMode {
        Button {
          onLyricsToggle()
        } label: {
          Image(systemName: "quote.bubble")
            .font(.system(size: 22))
            .foregroundColor(showLyrics ? .primary : .secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.85, dim: 0.55))
      }
      #if canImport(UIKit)
        ZStack {
          Image(systemName: routeSymbolName(audioManager.routeIcon))
            .font(.system(size: 22))
            .foregroundColor(.primary)
          AirPlayRoutePickerView()
            .frame(width: 44, height: 44)
        }
        .frame(maxWidth: audioManager.isRadioMode ? nil : .infinity)
      #endif
      Button {
        showingQueue = true
      } label: {
        Image(systemName: "list.bullet")
          .font(.system(size: 22))
          .foregroundColor(.primary)
          .frame(maxWidth: audioManager.isRadioMode ? nil : .infinity)
      }
      .buttonStyle(PressableButtonStyle(scale: 0.85, dim: 0.55))
    }
    .padding(.horizontal, audioManager.isRadioMode ? 0 : 48)
    .padding(.top, 16)
    .frame(maxWidth: .infinity)
  }
  private func routeSymbolName(_ name: String) -> String {
    #if canImport(UIKit)
      if UIImage(systemName: name) != nil { return name }
    #endif
    return "airplayaudio"
  }
}
