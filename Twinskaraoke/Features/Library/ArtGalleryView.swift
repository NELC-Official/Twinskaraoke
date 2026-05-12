import SwiftUI

struct ArtGalleryView: View {
  @StateObject private var viewModel = ArtGalleryViewModel()
  var body: some View {
    ScrollView {
      if viewModel.isLoading && viewModel.artists.isEmpty {
        LoadingIndicator(size: 64)
          .frame(maxWidth: .infinity)
          .padding(.top, 120)
      } else if viewModel.artists.isEmpty {
        VStack(spacing: 16) {
          Image(systemName: "paintpalette")
            .font(.system(size: 48))
            .foregroundColor(.secondary)
          Text("No artwork yet")
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
      } else {
        VStack(alignment: .leading, spacing: 28) {
          if let featured = featuredArt {
            NavigationLink {
              ArtDetailView(art: featured.art, artist: featured.artist)
            } label: {
              FeaturedArtCard(art: featured.art, artist: featured.artist)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 16)
          }
          if !topArtists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              GallerySectionHeader(title: "Featured Artists")
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                  ForEach(topArtists) { artist in
                    NavigationLink {
                      ArtistArtsView(artist: artist)
                    } label: {
                      ArtistCircleCard(artist: artist)
                    }
                    .buttonStyle(PressableButtonStyle())
                  }
                }
                .padding(.horizontal, 16)
              }
            }
          }
          VStack(alignment: .leading, spacing: 12) {
            GallerySectionHeader(title: "All Artists")
            LazyVStack(spacing: 0) {
              ForEach(Array(viewModel.artists.enumerated()), id: \.element.id) { idx, artist in
                NavigationLink {
                  ArtistArtsView(artist: artist)
                } label: {
                  ArtistListRow(artist: artist)
                }
                .buttonStyle(.plain)
                if idx < viewModel.artists.count - 1 {
                  Divider().padding(.leading, 78)
                }
              }
            }
            .padding(.horizontal, 16)
          }
        }
        .padding(.vertical, 16)
      }
    }
    .navigationTitle("Art Gallery")
    .navigationBarTitleDisplayMode(.large)
    .onAppear { viewModel.fetch() }
  }
  private var featuredArt: (art: GalleryArt, artist: GalleryArtist)? {
    for artist in viewModel.artists {
      if let art = artist.arts?.max(by: { ($0.upvotes ?? 0) < ($1.upvotes ?? 0) }) {
        return (art, artist)
      }
    }
    return nil
  }
  private var topArtists: [GalleryArtist] {
    Array(viewModel.artists.prefix(12))
  }
}

private struct GallerySectionHeader: View {
  let title: String
  var body: some View {
    Text(title)
      .font(.system(size: 22, weight: .bold))
      .padding(.horizontal, 16)
  }
}

private struct FeaturedArtCard: View {
  let art: GalleryArt
  let artist: GalleryArtist
  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Group {
        if let url = art.imageURL {
          LoadingImage(
            url: url, cornerRadius: 16, showsLoading: false, lowResURL: art.blurPreviewURL, transparentBackground: true)
        } else {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.tertiarySystemFill))
        }
      }
      .aspectRatio(4 / 5, contentMode: .fill)
      .frame(maxWidth: .infinity)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
      LinearGradient(
        colors: [.clear, .black.opacity(0.7)],
        startPoint: .center, endPoint: .bottom
      )
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .allowsHitTesting(false)
      VStack(alignment: .leading, spacing: 4) {
        Text("FEATURED ART")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.white.opacity(0.85))
          .tracking(0.6)
        Text(artist.name)
          .font(.system(size: 22, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(1)
        if let upvotes = art.upvotes, upvotes > 0 {
          Label("\(upvotes)", systemImage: "heart.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .padding(.top, 2)
        }
      }
      .padding(20)
    }
  }
}

private struct ArtistCircleCard: View {
  let artist: GalleryArtist
  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        if let art = artist.arts?.first, let url = art.imageURL {
          LoadingImage(
            url: url, cornerRadius: 100, showsLoading: false, lowResURL: art.blurPreviewURL, transparentBackground: true)
        } else {
          Circle()
            .fill(LinearGradient(
              colors: [Color.appAccent.opacity(0.85), Color.purple.opacity(0.85)],
              startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
              Text(initials(artist.name))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            )
        }
      }
      .frame(width: 96, height: 96)
      .clipShape(Circle())
      .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
      Text(artist.name)
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.primary)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .frame(width: 100)
    }
  }
  private func initials(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard let first = trimmed.first else { return "?" }
    return String(first).uppercased()
  }
}

private struct ArtistListRow: View {
  let artist: GalleryArtist
  var body: some View {
    HStack(spacing: 14) {
      Group {
        if let art = artist.arts?.first, let url = art.imageURL {
          LoadingImage(
            url: url, cornerRadius: 100, showsLoading: false, lowResURL: art.blurPreviewURL, transparentBackground: true)
        } else {
          Circle()
            .fill(LinearGradient(
              colors: [Color.appAccent.opacity(0.85), Color.purple.opacity(0.85)],
              startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
              Text(String(artist.name.first ?? "?").uppercased())
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            )
        }
      }
      .frame(width: 50, height: 50)
      .clipShape(Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(artist.name)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.primary)
          .lineLimit(1)
        Text("\(artist.arts?.count ?? 0) artworks")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.secondary.opacity(0.6))
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }
}
