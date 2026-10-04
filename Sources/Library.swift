import Foundation

@MainActor
final class Library: ObservableObject {
    @Published var user: UserInfo?
    @Published var playlists: [Playlist] = []
    @Published var likes: [Track] = []
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let u = try await SC.me()
            user = u
            playlists = try await SC.playlists(userID: u.id)
            likes = (try? await SC.likes(userID: u.id)) ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }
}
