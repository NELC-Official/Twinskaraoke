import LNPopupUI
import SwiftUI

struct ContentView: View {
  @StateObject var audioManager = AudioPlayerManager.shared
  var body: some View {
    PopupHostView()
      .environmentObject(audioManager)
  }
}

private struct PopupHostView: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    rootTabs
      .modifier(PopupModifier())
      .environmentObject(audioManager)
  }
  private var rootTabs: some View {
    TabView {
      HomeView()
        .tabItem { Label("Home", systemImage: "house.fill") }
      RadioView()
        .tabItem { Label("Radio", systemImage: "dot.radiowaves.left.and.right") }
      LibraryView()
        .tabItem { Label("Library", systemImage: "music.note.list") }
      SearchView()
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
      AccountView()
        .tabItem { Label("Account", systemImage: "person") }
    }
    .tint(.appAccent)
  }
}

private struct PopupModifier: ViewModifier {
  @EnvironmentObject var audioManager: AudioPlayerManager
  func body(content: Content) -> some View {
    content
      .popup(isBarPresented: .constant(audioManager.currentSong != nil),
             isPopupOpen: $audioManager.showFullScreen) {
        PopupContent()
          .environmentObject(audioManager)
      }
      .popupBarStyle(.floating)
      .popupCloseButtonStyle(.none)
      .popupInteractionStyle(.drag)
      .popupBarMarqueeScrollEnabled(false)
  }
}

private struct PopupContent: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    let song = audioManager.currentSong
    return FullScreenPlayerView()
      .environmentObject(audioManager)
      .popupTitle(song?.title ?? "", subtitle: song?.displayArtist ?? "")
      .popupImage(popupImage())
      .popupBarItems({
        PopupBarTrailingItems()
          .environmentObject(audioManager)
      })
  }
  private func popupImage() -> Image {
    if let ui = audioManager.nowPlayingArtwork {
      return Image(uiImage: ui)
    }
    return Image(systemName: "music.note")
  }
}

private struct PopupBarTrailingItems: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    HStack(spacing: 16) {
      Button {
        audioManager.togglePlayPause()
      } label: {
        Image(systemName: playPauseSymbol)
          .font(.system(size: 24, weight: .regular))
          .foregroundColor(.primary)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }
      if !audioManager.isRadioMode {
        Button {
          audioManager.playNextOrRandom()
        } label: {
          Image(systemName: "forward.fill")
            .font(.system(size: 22, weight: .regular))
            .foregroundColor(.primary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
      }
    }
  }
  private var playPauseSymbol: String {
    if audioManager.isRadioMode {
      return audioManager.isPlaying ? "stop.fill" : "play.fill"
    }
    return audioManager.isPlaying ? "pause.fill" : "play.fill"
  }
}

#Preview {
  ContentView()
}
