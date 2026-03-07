import Foundation

// Matches the server's notes table row
struct Note: Codable, Identifiable {
    let id: String
    let padKey: String
    var title: String
    var body: String          // JSON-encoded [TaskItem]
    var isShared: Bool
    var shareToken: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case padKey    = "pad_key"
        case isShared  = "is_shared"
        case shareToken = "share_token"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id may come as Int or String from the server
        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try c.decode(String.self, forKey: .id)
        }
        padKey     = (try? c.decode(String.self, forKey: .padKey)) ?? ""
        title      = (try? c.decode(String.self, forKey: .title)) ?? ""
        body       = (try? c.decode(String.self, forKey: .body)) ?? "[]"
        isShared   = (try? c.decode(Bool.self, forKey: .isShared)) ?? false
        shareToken = try? c.decode(String.self, forKey: .shareToken)
        updatedAt  = (try? c.decode(String.self, forKey: .updatedAt)) ?? ""
    }

    init(id: String, padKey: String, title: String, body: String,
         isShared: Bool, shareToken: String?, updatedAt: String) {
        self.id = id; self.padKey = padKey; self.title = title
        self.body = body; self.isShared = isShared
        self.shareToken = shareToken; self.updatedAt = updatedAt
    }

    // Decode the JSON body into TaskItem array
    var tasks: [TaskItem] {
        guard let data = body.data(using: .utf8),
              let list = try? JSONDecoder().decode([TaskItem].self, from: data)
        else { return [] }
        return list
    }
}

// A single task item stored inside note.body
struct TaskItem: Codable, Identifiable {
    var id: String
    var text: String
    var done: Bool
    var type: String?   // nil = regular, "divider" = section header

    var isDivider: Bool { type == "divider" }

    init(text: String, done: Bool = false, type: String? = nil) {
        self.id   = "\(Date().timeIntervalSince1970 * 1000)\(Int.random(in: 0..<10000))"
        self.text = text
        self.done = done
        self.type = type
    }
}

extension Array where Element == TaskItem {
    /// Encode back to the JSON string the server stores in note.body
    var jsonString: String {
        guard let data = try? JSONEncoder().encode(self),
              let str  = String(data: data, encoding: .utf8)
        else { return "[]" }
        return str
    }
}
