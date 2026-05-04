import SwiftUI

private struct ProfileResponse: Decodable {
    let profile: Profile
}

private struct Profile: Decodable {
    let displayName: String
    let avatarUrl: String?
}

struct AccountView: View {
    @StateObject private var auth = AuthManager()
    @EnvironmentObject var audioManager: AudioPlayerManager
    @State private var showLoginSheet = false
    @State private var profile: Profile?
    var body: some View {
        NavigationStack {
            List {
                profileSection
                generalSection
                if auth.isLoggedIn { signOutSection }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
            .sheet(isPresented: $showLoginSheet) {
                LoginSheet(auth: auth)
            }
            .task(id: auth.isLoggedIn) {
                if auth.isLoggedIn {
                    await loadData()
                    FavoritesManager.shared.reload()
                }
                else {
                    profile = nil
                    FavoritesManager.shared.clear()
                }
            }
        }
    }
    @ViewBuilder
    private var profileSection: some View {
        if auth.isLoggedIn {
            Section {
                NavigationLink {
                    Text("Profile").navigationTitle("Profile")
                } label: {
                    ProfileHeaderRow(
                        displayName: profile?.displayName ?? auth.currentUsername ?? "",
                        avatarUrl: profile?.avatarUrl ?? auth.currentAvatar
                    )
                }
            }
        } else {
            Section {
                Button { showLoginSheet = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color(.systemGray3))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sign In")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Sign in to access your library")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
    private var generalSection: some View {
        Section {
            NavigationLink {
                Text("Notifications").navigationTitle("Notifications")
            } label: {
                Label("Notifications", systemImage: "bell")
            }
            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            NavigationLink {
                AboutView()
            } label: {
                Label("About", systemImage: "info.circle")
            }
        }
    }
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) { auth.logout() } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
        }
    }
    private func loadData() async {
        guard let token = auth.authToken else { return }
        guard let url = URL(string: "https://api.neurokaraoke.com/api/badge/profile") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }
        profile = (try? JSONDecoder().decode(ProfileResponse.self, from: data))?.profile
    }
}

private struct ProfileHeaderRow: View {
    let displayName: String
    let avatarUrl: String?
    var body: some View {
        HStack(spacing: 16) {
            avatarView
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
    @ViewBuilder
    private var avatarView: some View {
        if let urlStr = avatarUrl, let url = URL(string: urlStr), !urlStr.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: initials
                }
            }
        } else {
            initials
        }
    }
    private var initials: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "7C5CFC"), Color(hex: "B47BFF")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(displayName.prefix(1).uppercased()))
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct LoginSheet: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focus: LoginField?
    private enum LoginField { case username, password }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn() }
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let err = auth.errorMessage, !err.isEmpty {
                    Section {
                        Label(err, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    .listRowBackground(Color.red.opacity(0.07))
                }
                Section {
                    Button(action: signIn) {
                        HStack {
                            Spacer()
                            Group {
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Spacer()
                        }
                        .frame(height: 44)
                        .background(
                            LinearGradient(colors: [Color(hex: "7C5CFC"), Color(hex: "B47BFF")],
                                           startPoint: .leading, endPoint: .trailing)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        )
                    }
                    .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
                    .opacity(username.isEmpty || password.isEmpty ? 0.55 : 1)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                Section {
                    Button {
                        Task { await auth.loginWithDiscord() }
                    } label: {
                        HStack {
                            Spacer()
                            HStack(spacing: 10) {
                                DiscordIcon(size: 20, color: .white)
                                Text("Continue with Discord")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 44)
                        .background(
                            Color(hex: "5865F2")
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        )
                    }
                    .disabled(auth.isLoading)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("TwinsKaraoke")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: auth.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn { dismiss() }
            }
        }
    }
    private func signIn() {
        focus = nil
        Task { await auth.login(username: username, password: password) }
    }
}

private struct DiscordIcon: View {
    var size: CGFloat = 20
    var color: Color = .white
    var body: some View {
        DiscordShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: size, height: size * 55 / 71)
    }
}

private struct DiscordShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: .init(x: w * 0.847, y: h * 0.089))
        p.addCurve(to: .init(x: w * 0.643, y: 0),
                   control1: .init(x: w * 0.820, y: h * 0.040),
                   control2: .init(x: w * 0.735, y: 0))
        p.addCurve(to: .init(x: w * 0.570, y: h * 0.070),
                   control1: .init(x: w * 0.614, y: 0),
                   control2: .init(x: w * 0.587, y: h * 0.028))
        p.addCurve(to: .init(x: w * 0.430, y: h * 0.070),
                   control1: .init(x: w * 0.535, y: h * 0.098),
                   control2: .init(x: w * 0.465, y: h * 0.098))
        p.addCurve(to: .init(x: w * 0.357, y: 0),
                   control1: .init(x: w * 0.413, y: h * 0.028),
                   control2: .init(x: w * 0.386, y: 0))
        p.addCurve(to: .init(x: w * 0.153, y: h * 0.089),
                   control1: .init(x: w * 0.265, y: 0),
                   control2: .init(x: w * 0.180, y: h * 0.040))
        p.addCurve(to: .init(x: w * 0.004, y: h * 0.818),
                   control1: .init(x: w * -0.028, y: h * 0.237),
                   control2: .init(x: w * -0.043, y: h * 0.580))
        p.addCurve(to: .init(x: w * 0.251, y: h),
                   control1: .init(x: w * 0.044, y: h * 0.954),
                   control2: .init(x: w * 0.141, y: h))
        p.addCurve(to: .init(x: w * 0.307, y: h * 0.873),
                   control1: .init(x: w * 0.290, y: h),
                   control2: .init(x: w * 0.307, y: h * 0.929))
        p.addCurve(to: .init(x: w * 0.693, y: h * 0.873),
                   control1: .init(x: w * 0.407, y: h * 0.818),
                   control2: .init(x: w * 0.593, y: h * 0.818))
        p.addCurve(to: .init(x: w * 0.749, y: h),
                   control1: .init(x: w * 0.693, y: h * 0.929),
                   control2: .init(x: w * 0.710, y: h))
        p.addCurve(to: .init(x: w, y: h * 0.818),
                   control1: .init(x: w * 0.860, y: h),
                   control2: .init(x: w * 0.957, y: h * 0.954))
        p.addCurve(to: .init(x: w * 0.847, y: h * 0.089),
                   control1: .init(x: w * 1.043, y: h * 0.580),
                   control2: .init(x: w * 1.028, y: h * 0.237))
        p.closeSubpath()
        p.addEllipse(in: .init(x: w * 0.245, y: h * 0.418, width: w * 0.178, height: h * 0.254))
        p.addEllipse(in: .init(x: w * 0.577, y: h * 0.418, width: w * 0.178, height: h * 0.254))
        return p
    }
}
fileprivate extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(v>>8)*17,(v>>4&0xF)*17,(v&0xF)*17)
        case 6:  (a,r,g,b) = (255,v>>16,v>>8&0xFF,v&0xFF)
        case 8:  (a,r,g,b) = (v>>24,v>>16&0xFF,v>>8&0xFF,v&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}
