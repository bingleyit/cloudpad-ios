import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var user: User?
    @Published var token: String?

    var isLoggedIn: Bool { token != nil && user != nil }

    var accentColor: Color {
        Color(hex: resolvedAccentHex)
    }

    /// Resolves the theme field to a hex string.
    /// The server stores either a hex ("#9361ff") or a legacy name ("dusk").
    var resolvedAccentHex: String {
        guard let theme = user?.theme, !theme.isEmpty else {
            return Config.defaultAccent
        }
        if theme.hasPrefix("#") { return theme }
        return Config.themeHexMap[theme] ?? Config.defaultAccent
    }

    init() {
        self.token = Keychain.get("cp_token")
        if let data = UserDefaults.standard.data(forKey: "cp_user"),
           let saved = try? JSONDecoder().decode(User.self, from: data) {
            self.user = saved
        }
    }

    func login(token: String, user: User) {
        self.token = token
        self.user  = user
        Keychain.set("cp_token", value: token)
        persist(user)
    }

    func updateUser(_ user: User) {
        self.user = user
        persist(user)
    }

    func logout() {
        token = nil
        user  = nil
        Keychain.delete("cp_token")
        UserDefaults.standard.removeObject(forKey: "cp_user")
    }

    private func persist(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "cp_user")
        }
    }
}

// MARK: – Color from hex

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        let val = UInt64(h, radix: 16) ?? 0x9361ff
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >>  8) & 0xFF) / 255
        let b = Double( val        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
