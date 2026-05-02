import SwiftUI

struct SongListView: View {
  let title: String
  let songs: [Song]
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    List(songs) { song in
      Button {
        audioManager.play(song: song, context: songs)
      } label: {
        SearchResultRow(song: song)
      }
      .buttonStyle(PressableButtonStyle())
      .listRowBackground(Color.clear)
      .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
    .listStyle(.plain)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.large)
  }
}
