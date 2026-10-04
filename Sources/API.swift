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

struct SearchResponse: Decodable { let collection: [Track] }

enum SC {
    static let defaultID = "yNSW5UvBmb1A5j7qPUtIMuB9Itx3jsOC"
    static var clientID: String {
        let v = UserDefaults.standard.string(forKey: "client_id") ?? ""
        return v.isEmpty ? defaultID : v
    }

    static func search(_ q: String) async throws -> [Track] {
        var c = URLComponents(string: "https://api-v2.soundcloud.com/search/tracks")!
        c.queryItems = [
            .init(name: "q", value: q),
            .init(name: "client_id", value: clientID),
            .init(name: "limit", value: "30"),
        ]
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        return try JSONDecoder().decode(SearchResponse.self, from: data).collection
    }

    static func streamURL(for t: Track) async throws -> URL {
        let list = t.media?.transcodings ?? []
        guard let tc = list.first(where: { $0.format.proto == "progressive" })
                ?? list.first(where: { $0.format.proto == "hls" })
        else { throw URLError(.resourceUnavailable) }

        var c = URLComponents(string: tc.url)!
        var items = [URLQueryItem(name: "client_id", value: clientID)]
        if let a = t.track_authorization { items.append(.init(name: "track_authorization", value: a)) }
        c.queryItems = items

        struct R: Decodable { let url: String }
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        let r = try JSONDecoder().decode(R.self, from: data)
        guard let u = URL(string: r.url) else { throw URLError(.badURL) }
        return u
    }
}
