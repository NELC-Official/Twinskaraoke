import SwiftUI

extension Color {
  /// Apple Music accent color — appears red on light backgrounds and a slightly lifted
  /// red-pink on dark backgrounds. Defined via the asset catalog if present, otherwise
  /// via dynamic UIColor that adapts to the user's interface style.
  static let appAccent: Color = {
    #if canImport(UIKit)
    return Color(uiColor: UIColor { trait in
      switch trait.userInterfaceStyle {
      case .dark:
        return UIColor(red: 1.00, green: 0.29, blue: 0.40, alpha: 1) // #FF4A66
      default:
        return UIColor(red: 0.98, green: 0.14, blue: 0.24, alpha: 1) // #FA243C
      }
    })
    #else
    return Color(red: 0.98, green: 0.14, blue: 0.24)
    #endif
  }()
}
