import SwiftUI

struct NowPlayingBarContainer: View {
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    Group {
      if audioManager.currentSong != nil {
        NowPlayingBar()
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: audioManager.currentSong != nil)
  }
}

struct ContentView: View {
  @StateObject var audioManager = AudioPlayerManager.shared
  var body: some View {
    TabView {
      HomeView()
        .safeAreaInset(edge: .bottom, spacing: 0) { NowPlayingBarContainer() }
        .tabItem { Label("Home", systemImage: "house.fill") }
      RadioView()
        .safeAreaInset(edge: .bottom, spacing: 0) { NowPlayingBarContainer() }
        .tabItem { Label("Radio", systemImage: "dot.radiowaves.left.and.right") }
      LibraryView()
        .safeAreaInset(edge: .bottom, spacing: 0) { NowPlayingBarContainer() }
        .tabItem { Label("Library", systemImage: "music.note.list") }
      SearchView()
        .safeAreaInset(edge: .bottom, spacing: 0) { NowPlayingBarContainer() }
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
      AccountView()
        .safeAreaInset(edge: .bottom, spacing: 0) { NowPlayingBarContainer() }
        .tabItem { Label("Account", systemImage: "person") }
    }
    .tint(.appAccent)
    .onAppear {
      let appearance = UITabBarAppearance()
      appearance.configureWithTransparentBackground()
      appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
      appearance.backgroundColor = UIColor.clear
      UITabBar.appearance().standardAppearance = appearance
      UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    .sheet(isPresented: $audioManager.showFullScreen) {
      FullScreenPlayerView()
        .environmentObject(audioManager)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .interactiveDismissDisabled(false)
    }
    .environmentObject(audioManager)
  }
}

#Preview {
  ContentView()
}
