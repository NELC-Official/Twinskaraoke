import SwiftUI

/// Shared `Namespace` for matched-geometry transitions between the mini player bar
/// and the full-screen player. Injected from `ContentView` and consumed by
/// `NowPlayingBar` / `FullScreenPlayerView`.

struct PlayerNamespace {
  let id: Namespace.ID
}

private struct PlayerNamespaceKey: EnvironmentKey {
  static let defaultValue: PlayerNamespace? = nil
}

extension EnvironmentValues {
  var playerNamespace: PlayerNamespace? {
    get { self[PlayerNamespaceKey.self] }
    set { self[PlayerNamespaceKey.self] = newValue }
  }
}

enum PlayerMatchedID {
  static let artwork = "player.artwork"
  static let title = "player.title"
}
