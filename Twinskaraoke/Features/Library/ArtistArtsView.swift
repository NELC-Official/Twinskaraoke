import SwiftUI

struct ArtistArtsView: View {
  let artist: GalleryArtist
  private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
  var body: some View {
    let arts = artist.arts ?? []
    ScrollView {
      VStack(spacing: 18) {
        if let hero = arts.first, let heroURL = hero.imageURL {
          LoadingImage(
            url: heroURL, cornerRadius: 14, showsLoading: false, lowResURL: hero.blurPreviewURL,
            transparentBackground: true
          )
          .aspectRatio(1, contentMode: .fit)
          .frame(width: 240, height: 240)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
        }
        VStack(spacing: 4) {
          Text(artist.name)
            .font(.title2.bold())
            .multilineTextAlignment(.center)
          if let social = artist.socialLink, !social.isEmpty {
            Text(social)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          Text("\(arts.count) artworks")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        if !arts.isEmpty {
          LazyVGrid(columns: cols, spacing: 8) {
            ForEach(arts) { art in
              NavigationLink {
                ArtDetailView(art: art, artist: artist)
              } label: {
                ArtThumbnail(art: art)
              }
              .buttonStyle(PressableButtonStyle())
            }
          }
          .padding(.horizontal, 8)
        } else {
          VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
              .font(.system(size: 40))
              .foregroundColor(.secondary)
            Text("No artwork yet")
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 40)
        }
      }
      .padding(.top, 12)
      .padding(.bottom, 16)
    }
    .navigationTitle(artist.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct ArtThumbnail: View {
  let art: GalleryArt
  var body: some View {
    Group {
      if let url = art.imageURL {
        LoadingImage(
          url: url, cornerRadius: 8, showsLoading: false, lowResURL: art.blurPreviewURL, transparentBackground: true)
      } else {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(Color(.tertiarySystemFill))
      }
    }
    .aspectRatio(1, contentMode: .fill)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}
