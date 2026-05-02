import SwiftUI

struct RandomSongsView: View {
  @StateObject var viewModel = RandomSongsViewModel()
  @EnvironmentObject var audioManager: AudioPlayerManager
  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        artworkMosaic
          .frame(width: 240, height: 240)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        VStack(spacing: 4) {
          Text("Random Songs")
            .font(.title2.bold())
            .multilineTextAlignment(.center)
          Text(viewModel.songs.isEmpty ? "Tap refresh to roll" : "\(viewModel.songs.count) songs")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        if !viewModel.songs.isEmpty {
          HStack(spacing: 12) {
            Button {
              if let first = viewModel.songs.first {
                audioManager.play(song: first, context: viewModel.songs)
              }
            } label: {
              actionLabel(symbol: "play.fill", text: "Play")
            }
            .buttonStyle(PressableButtonStyle())
            Button {
              if let random = viewModel.songs.randomElement() {
                audioManager.play(song: random, context: viewModel.songs.shuffled())
              }
            } label: {
              actionLabel(symbol: "shuffle", text: "Shuffle")
            }
            .buttonStyle(PressableButtonStyle())
          }
          .padding(.horizontal)
          LazyVStack(spacing: 0) {
            ForEach(viewModel.songs) { song in
              Button {
                audioManager.play(song: song, context: viewModel.songs)
              } label: {
                SongRow(song: song, size: .regular)
                  .padding(.horizontal)
                  .padding(.vertical, 8)
              }
              .buttonStyle(PressableButtonStyle())
              Divider().padding(.leading, 76)
            }
          }
        } else if viewModel.isLoading {
          VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
              SongRowSkeleton(size: .regular)
                .padding(.horizontal)
              Divider().padding(.leading, 76)
            }
          }
        }
      }
      .padding(.top, 12)
      .padding(.bottom, 16)
    }
    .navigationTitle("Random")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          viewModel.fetch()
        } label: {
          Image(systemName: "arrow.triangle.2.circlepath")
        }
      }
    }
    .onAppear {
      if viewModel.songs.isEmpty { viewModel.fetch() }
    }
  }
  @ViewBuilder
  private var artworkMosaic: some View {
    let arts = Array(viewModel.songs.prefix(4).compactMap { $0.imageURL })
    if arts.count >= 4 {
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
        ForEach(0..<4, id: \.self) { i in
          LoadingImage(url: arts[i], cornerRadius: 0)
            .aspectRatio(1, contentMode: .fill)
        }
      }
    } else if let url = arts.first {
      LoadingImage(url: url, cornerRadius: 0)
    } else {
      LinearGradient(
        colors: [Color.appAccent.opacity(0.85), Color.purple.opacity(0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .overlay(
        Image(systemName: "shuffle")
          .font(.system(size: 64, weight: .medium))
          .foregroundColor(.white.opacity(0.85))
      )
    }
  }
  private func actionLabel(symbol: String, text: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
      Text(text).fontWeight(.semibold)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .foregroundColor(.appAccent)
    .background(Color(.tertiarySystemFill))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}
