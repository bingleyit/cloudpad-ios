import Foundation

struct User: Codable {
    let id: String
    let email: String
    let name: String
    var displayName: String     // display_name (overrides name in UI)
    var theme: String           // hex string OR legacy name e.g. "dusk" → resolved to hex in AppState
    var mood: String
    var bg: String
    var avatar: String
    var colOpacity: Double
    var profileImage: String
    var tickerPrefs: String
    var workspaceName: String
    var fontPref: String
    var padOrder: String
    var handle: String
    var padMeta: String
    var plan: String            // "free" | "pro" | "lifetime"
    var betaMode: Bool
    var location: String
    var timezone: String

    enum CodingKeys: String, CodingKey {
        case id, email, name, displayName, theme, mood, bg, avatar
        case colOpacity, profileImage, tickerPrefs, workspaceName
        case fontPref, padOrder, handle, padMeta, plan, betaMode
        case location, timezone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id may come as Int or String from the server
        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try c.decode(String.self, forKey: .id)
        }
        email         = try c.decode(String.self, forKey: .email)
        name          = (try? c.decode(String.self, forKey: .name)) ?? ""
        displayName   = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        theme         = (try? c.decode(String.self, forKey: .theme)) ?? "dusk"
        mood          = (try? c.decode(String.self, forKey: .mood)) ?? "dusk"
        bg            = (try? c.decode(String.self, forKey: .bg)) ?? ""
        avatar        = (try? c.decode(String.self, forKey: .avatar)) ?? "🌸"
        colOpacity    = (try? c.decode(Double.self, forKey: .colOpacity)) ?? 0.92
        profileImage  = (try? c.decode(String.self, forKey: .profileImage)) ?? ""
        tickerPrefs   = (try? c.decode(String.self, forKey: .tickerPrefs)) ?? ""
        workspaceName = (try? c.decode(String.self, forKey: .workspaceName)) ?? ""
        fontPref      = (try? c.decode(String.self, forKey: .fontPref)) ?? ""
        padOrder      = (try? c.decode(String.self, forKey: .padOrder)) ?? ""
        handle        = (try? c.decode(String.self, forKey: .handle)) ?? ""
        padMeta       = (try? c.decode(String.self, forKey: .padMeta)) ?? ""
        plan          = (try? c.decode(String.self, forKey: .plan)) ?? "free"
        betaMode      = (try? c.decode(Bool.self, forKey: .betaMode)) ?? false
        location      = (try? c.decode(String.self, forKey: .location)) ?? ""
        timezone      = (try? c.decode(String.self, forKey: .timezone)) ?? ""
    }

    init(
        id: String = "", email: String = "", name: String = "",
        displayName: String = "",
        theme: String = "dusk", mood: String = "dusk",
        bg: String = "", avatar: String = "🌸",
        colOpacity: Double = 0.92, profileImage: String = "",
        tickerPrefs: String = "", workspaceName: String = "",
        fontPref: String = "", padOrder: String = "",
        handle: String = "", padMeta: String = "",
        plan: String = "free", betaMode: Bool = false,
        location: String = "", timezone: String = ""
    ) {
        self.id = id; self.email = email; self.name = name
        self.displayName = displayName; self.theme = theme; self.mood = mood
        self.bg = bg; self.avatar = avatar; self.colOpacity = colOpacity
        self.profileImage = profileImage; self.tickerPrefs = tickerPrefs
        self.workspaceName = workspaceName; self.fontPref = fontPref
        self.padOrder = padOrder; self.handle = handle; self.padMeta = padMeta
        self.plan = plan; self.betaMode = betaMode
        self.location = location; self.timezone = timezone
    }

    /// The name shown in the UI — displayName takes priority over name
    var visibleName: String { displayName.isEmpty ? name : displayName }
}
