import Foundation

enum GuestIdentity {
  private static let storageKey = "nk.guestId"
  static let current: String = {
    let defaults = UserDefaults.standard
    if let existing = defaults.string(forKey: storageKey), !existing.isEmpty {
      return existing
    }
    let generated = UUID().uuidString.lowercased()
    defaults.set(generated, forKey: storageKey)
    return generated
  }()
}
