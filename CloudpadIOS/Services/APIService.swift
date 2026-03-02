import Foundation

enum APIError: LocalizedError {
    case network(String)
    case server(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .network(let m):  return "Network error: \(m)"
        case .server(let m):   return m
        case .unauthorized:    return "Session expired. Please log in again."
        }
    }
}

// MARK: – Auth response shapes

struct AuthResponse: Decodable {
    let token: String
    let user: User
}

struct NotesResponse: Decodable {
    let notes: [Note]
}

struct NoteResponse: Decodable {
    let note: Note?
}

struct ShareResponse: Decodable {
    let shareUrl: String
    let token: String
}

struct UserResponse: Decodable {
    let user: User
}

// MARK: – Service

actor APIService {
    static let shared = APIService()
    private init() {}

    // Inject token per-call so the actor stays stateless
    private func request(
        method: String,
        path: String,
        token: String?,
        body: Encodable? = nil
    ) async throws -> Data {
        guard let url = URL(string: Config.baseURL + path) else {
            throw APIError.network("Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        if let b = body {
            req.httpBody = try JSONEncoder().encode(b)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("No HTTP response")
        }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode >= 400 {
            // Try to decode { error: "..." }
            if let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] {
                throw APIError.server(msg)
            }
            throw APIError.server("Server error \(http.statusCode)")
        }
        return data
    }

    // MARK: Auth

    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        struct Body: Encodable { let email, password, name: String }
        let data = try await request(method: "POST", path: "/api/auth/register", token: nil,
                                     body: Body(email: email, password: password, name: name))
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let email, password: String }
        let data = try await request(method: "POST", path: "/api/auth/login", token: nil,
                                     body: Body(email: email, password: password))
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    // MARK: Notes

    func fetchAllNotes(token: String) async throws -> [Note] {
        let data = try await request(method: "GET", path: "/api/notes", token: token)
        return try JSONDecoder().decode(NotesResponse.self, from: data).notes
    }

    func fetchNote(padKey: String, token: String) async throws -> Note? {
        let enc = padKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? padKey
        let data = try await request(method: "GET", path: "/api/notes/\(enc)", token: token)
        return try JSONDecoder().decode(NoteResponse.self, from: data).note
    }

    func saveNote(padKey: String, title: String, body: String, token: String) async throws {
        struct Body: Encodable { let title, body: String }
        let enc = padKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? padKey
        _ = try await request(method: "PUT", path: "/api/notes/\(enc)", token: token,
                               body: Body(title: title, body: body))
    }

    func deleteNote(padKey: String, token: String) async throws {
        let enc = padKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? padKey
        _ = try await request(method: "DELETE", path: "/api/notes/\(enc)", token: token)
    }

    // MARK: Sharing

    func shareNote(padKey: String, token: String) async throws -> ShareResponse {
        let enc = padKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? padKey
        let data = try await request(method: "POST", path: "/api/notes/\(enc)/share", token: token)
        return try JSONDecoder().decode(ShareResponse.self, from: data)
    }

    func unshareNote(padKey: String, token: String) async throws {
        let enc = padKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? padKey
        _ = try await request(method: "DELETE", path: "/api/notes/\(enc)/share", token: token)
    }

    // MARK: User

    func fetchMe(token: String) async throws -> User {
        let data = try await request(method: "GET", path: "/api/user/me", token: token)
        return try JSONDecoder().decode(UserResponse.self, from: data).user
    }

    // MARK: Preferences

    struct PreferencesBody: Encodable {
        var theme: String?
        var mood: String?
        var bg: String?
        var colOpacity: Double?
        var profileImage: String?
        var workspaceName: String?
        var fontPref: String?
        var padOrder: String?
        var displayName: String?
        var name: String?
        var handle: String?
        var padMeta: String?
        var betaMode: Bool?
        var location: String?
        var timezone: String?
    }

    func updatePreferences(_ body: PreferencesBody, token: String) async throws -> User {
        let data = try await request(method: "PATCH", path: "/api/user/preferences",
                                     token: token, body: body)
        return try JSONDecoder().decode(UserResponse.self, from: data).user
    }
}
