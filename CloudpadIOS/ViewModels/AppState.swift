import Combine
import SwiftUI
import UIKit

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
        updateAppIcon()
    }

    /// Refresh user + theme from the server (called on foreground, login, etc.)
    func syncFromServer() async {
        guard let token else { return }
        if let fresh = try? await APIService.shared.fetchMe(token: token) {
            updateUser(fresh)
        }
    }

    // MARK: – Adaptive app icon

    /// Switches the home-screen icon to match the current theme colour.
    /// Maps preset hex values to pre-registered alternate icon names.
    func updateAppIcon() {
        let iconName = iconNameForTheme(resolvedAccentHex)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let current = UIApplication.shared.alternateIconName
        guard current != iconName else { return }
        UIApplication.shared.setAlternateIconName(iconName) { _ in }
    }

    private func iconNameForTheme(_ hex: String) -> String? {
        switch hex.lowercased() {
        case "#c0607a": return "cloudpad-rose"
        case "#4a7fb0": return "cloudpad-sky"
        case "#3a9e78": return "cloudpad-mint"
        case "#b08820": return "cloudpad-gold"
        case "#e05a20": return "cloudpad-orange"
        case "#1a1714": return "cloudpad-ink"
        default:        return "cloudpad-purple" // covers #7c5cbf, #9361ff, unknown
        }
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
