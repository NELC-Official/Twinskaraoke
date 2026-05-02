import SwiftUI

struct ContentView: View {
  @StateObject var audioManager = WatchAudioManager.shared
  var body: some View {
    WatchHomeView()
      .environmentObject(audioManager)
  }
}

#Preview {
  ContentView()
}
