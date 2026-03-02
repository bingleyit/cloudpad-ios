import Foundation

enum Config {
    // Your Railway URL — copy from Railway dashboard → your service → Settings → Domains
    static let baseURL = "https://cloudpad-production.up.railway.app"

    // Special pads shown in the sidebar (matches web app PADS constant)
    static let specialPads: [(key: String, label: String, icon: String)] = [
        ("personal", "Personal",  "person"),
        ("someday",  "Someday",   "clock"),
        ("shopping", "Shopping",  "cart"),
        ("ideas",    "Ideas",     "lightbulb"),
        ("life",     "Life",      "heart"),
    ]

    // Default accent — matches the web app's CSS `--accent: #9361ff`
    static let defaultAccent = "#9361ff"

    // Preset swatches shown on the web app's mood/accent screen
    static let accentPresets: [(name: String, hex: String)] = [
        ("Purple", "#7c5cbf"),
        ("Rose",   "#c0607a"),
        ("Sky",    "#4a7fb0"),
        ("Mint",   "#3a9e78"),
        ("Gold",   "#b08820"),
        ("Orange", "#e05a20"),
        ("Ink",    "#1a1714"),
    ]

    // Legacy named theme values the server may return → resolved to hex
    static let themeHexMap: [String: String] = [
        "default": "#9361ff",
        "rose":    "#c0607a",
        "sky":     "#4a7fb0",
        "mint":    "#3a9e78",
        "gold":    "#b08820",
        "ocean":   "#3a5a8a",
        "aurora":  "#9a3a7a",
        "dusk":    "#7c5cbf",
    ]
}
