import Foundation

struct Track: Identifiable, Decodable {
    let id: Int
    let title: String
    let artwork_url: String?
    let track_authorization: String?
    let user: User
    let media: Media?

    struct User: Decodable { let username: String }
    struct Media: Decodable { let transcodings: [Transcoding] }
    struct Transcoding: Decodable {
        let url: String
        let format: Format
        struct Format: Decodable {
            let proto: String
            enum CodingKeys: String, CodingKey { case proto = "protocol" }
        }
    }

    var artworkURL: URL? {
        artwork_url.flatMap { URL(string: $0.replacingOccurrences(of: "-large", with: "-t300x300")) }
    }
}

struct Page<T: Decodable>: Decodable { let collection: [T] }
struct UserInfo: Decodable { let id: Int; let username: String }
struct TrackID: Decodable { let id: Int }

struct Playlist: Identifiable, Decodable {
    let id: Int
    let title: String
    let track_count: Int?
    let artwork_url: String?
    let tracks: [TrackID]?
}

struct Like: Decodable {
    let track: Track?
    enum CodingKeys: String, CodingKey { case track }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        track = try? c.decode(Track.self, forKey: .track)
    }
}

enum APIError: LocalizedError {
    case http(Int)
    case noProfile
    var errorDescription: String? {
        switch self {
        case .http(let c) where c == 401 || c == 403:
            return "Ключ или токен не подходит (\(c)). Проверь настройки."
        case .http(let c):
            return "Ошибка сервера: \(c)"
        case .noProfile:
            return "Укажи профиль или токен во вкладке «Настройки»."
        }
    }
}

enum SC {
    static let defaultID = "yNSW5UvBmb1A5j7qPUtIMuB9Itx3jsOC"
    private static func pref(_ k: String) -> String { UserDefaults.standard.string(forKey: k) ?? "" }
    static var clientID: String { let v = pref("client_id"); return v.isEmpty ? defaultID : v }
    static var token: String { pref("oauth_token").trimmingCharacters(in: .whitespacesAndNewlines) }
    static var profile: String { pref("profile").trimmingCharacters(in: .whitespacesAndNewlines) }

    static func fetch(_ url: URL) async throws -> Data {
        var r = URLRequest(url: url)
        if !token.isEmpty { r.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization") }
        let (d, resp) = try await URLSession.shared.data(for: r)
        if let h = resp as? HTTPURLResponse, h.statusCode >= 400 { throw APIError.http(h.statusCode) }
        return d
    }

    static func get<T: Decodable>(_ path: String, _ q: [String: String] = [:]) async throws -> T {
        var c = URLComponents(string: "https://api-v2.soundcloud.com" + path)!
        var items = q.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "client_id", value: clientID))
        c.queryItems = items
        let d = try await fetch(c.url!)
        return try JSONDecoder().decode(T.self, from: d)
    }

    static func search(_ q: String) async throws -> [Track] {
        let r: Page<Track> = try await get("/search/tracks", ["q": q, "limit": "30"])
        return r.collection
    }

    static func me() async throws -> UserInfo {
        if !token.isEmpty { return try await get("/me") }
        let p = profile
        guard !p.isEmpty else { throw APIError.noProfile }
        let url = p.hasPrefix("http") ? p : "https://soundcloud.com/" + p
        return try await get("/resolve", ["url": url])
    }

    static func playlists(userID: Int) async throws -> [Playlist] {
        let r: Page<Playlist> = try await get("/users/\(userID)/playlists_without_albums", ["limit": "50"])
        return r.collection
    }

    static func likes(userID: Int) async throws -> [Track] {
        let r: Page<Like> = try await get("/users/\(userID)/track_likes", ["limit": "50"])
        return r.collection.compactMap { $0.track }
    }

    static func tracks(of p: Playlist) async throws -> [Track] {
        let full: Playlist = try await get("/playlists/\(p.id)")
        let ids = (full.tracks ?? []).map { $0.id }
        var byID: [Int: Track] = [:]
        var start = 0
        while start < ids.count {
            let chunk = Array(ids[start..<min(start + 50, ids.count)])
            let list: [Track] = try await get("/tracks", ["ids": chunk.map { String($0) }.joined(separator: ",")])
            for t in list { byID[t.id] = t }
            start += 50
        }
        return ids.compactMap { byID[$0] }
    }

    static func streamURL(for t: Track) async throws -> URL {
        let list = t.media?.transcodings ?? []
        guard let tc = list.first(where: { $0.format.proto == "progressive" })
                ?? list.first(where: { $0.format.proto == "hls" })
        else { throw URLError(.resourceUnavailable) }

        var c = URLComponents(string: tc.url)!
        var items = [URLQueryItem(name: "client_id", value: clientID)]
        if let a = t.track_authorization { items.append(URLQueryItem(name: "track_authorization", value: a)) }
        c.queryItems = items

        struct R: Decodable { let url: String }
        let d = try await fetch(c.url!)
        let r = try JSONDecoder().decode(R.self, from: d)
        guard let u = URL(string: r.url) else { throw URLError(.badURL) }
        return u
    }
}
