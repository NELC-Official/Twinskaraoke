import Foundation

enum EQPreset: String, CaseIterable, Identifiable {
  case flat = "Flat"
  case bass = "Bass Boost"
  case treble = "Treble Boost"
  case vocal = "Vocal"
  case rock = "Rock"
  case pop = "Pop"
  case jazz = "Jazz"
  case electronic = "Electronic"
  case classical = "Classical"
  case hiphop = "Hip-Hop"
  case loudness = "Loudness"
  case custom = "Custom"

  var id: String { rawValue }

  var gains: [Float] {
    switch self {
    case .flat:       return [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0]
    case .bass:       return [10,  8,  5,  2,  0,  0,  0,  0,  0,  0]
    case .treble:     return [ 0,  0,  0,  0,  0,  2,  4,  6,  8, 10]
    case .vocal:      return [-2, -1,  0,  3,  6,  6,  4,  2,  0, -1]
    case .rock:       return [ 5,  4,  2,  0, -2, -1,  2,  4,  5,  6]
    case .pop:        return [-1,  2,  4,  5,  3,  0, -1,  0,  2,  3]
    case .jazz:       return [ 3,  2,  0,  2,  4,  4,  2,  3,  4,  3]
    case .electronic: return [ 6,  5,  2,  0, -2,  2,  1,  4,  6,  7]
    case .classical:  return [ 4,  3,  2,  1, -1, -1,  0,  2,  3,  4]
    case .hiphop:     return [ 7,  6,  3,  1,  0,  0,  1,  2,  4,  3]
    case .loudness:   return [ 8,  5,  0, -2, -4, -2,  0,  3,  6,  8]
    case .custom:     return [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0]
    }
  }
}
