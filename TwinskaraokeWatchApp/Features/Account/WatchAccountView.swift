import SwiftUI

struct WatchAccountView: View {
  var body: some View {
    List {
      Section {
        HStack(spacing: 12) {
          Image(systemName: "person.circle.fill")
            .font(.system(size: 36))
            .foregroundColor(.secondary)
          VStack(alignment: .leading, spacing: 2) {
            Text("Guest")
              .font(.system(size: 15, weight: .semibold))
            Text("Not signed in")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
          }
        }
      }
      Section("Guest ID") {
        Text(String(GuestIdentity.current.prefix(8)) + "...")
          .font(.system(size: 12, design: .monospaced))
          .foregroundColor(.secondary)
      }
      Section {
        HStack {
          Image(systemName: "iphone")
            .foregroundColor(.blue)
          Text("Sign in on iPhone")
            .font(.system(size: 13))
        }
        .foregroundColor(.secondary)
      }
    }
    .navigationTitle("Account")
  }
}
