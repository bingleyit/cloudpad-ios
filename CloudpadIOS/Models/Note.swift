import Foundation

// Matches the server's notes table row
struct Note: Codable, Identifiable {
    let id: String
    let padKey: String
    var title: String
    var body: String          // JSON-encoded [Task]
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

    // Decode the JSON body into Task array
    var tasks: [Task] {
        guard let data = body.data(using: .utf8),
              let list = try? JSONDecoder().decode([Task].self, from: data)
        else { return [] }
        return list
    }
}

// A single task item stored inside note.body
struct Task: Codable, Identifiable {
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

extension Array where Element == Task {
    /// Encode back to the JSON string the server stores in note.body
    var jsonString: String {
        guard let data = try? JSONEncoder().encode(self),
              let str  = String(data: data, encoding: .utf8)
        else { return "[]" }
        return str
    }
}
