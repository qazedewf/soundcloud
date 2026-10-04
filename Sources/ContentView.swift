import SwiftUI

struct ContentView: View {
    @StateObject private var player = Player()
    @StateObject private var library = Library()

    var body: some View {
        TabView {
            SearchTab().tabItem { Label("Поиск", systemImage: "magnifyingglass") }
            PlaylistsTab().tabItem { Label("Плейлисты", systemImage: "music.note.list") }
            LikesTab().tabItem { Label("Лайки", systemImage: "heart") }
            SettingsTab().tabItem { Label("Настройки", systemImage: "gear") }
        }
        .environmentObject(player)
        .environmentObject(library)
        .task { await library.load() }
    }
}

// MARK: - Tabs

struct SearchTab: View {
    @State private var query = ""
    @State private var tracks: [Track] = []
    @State private var error: String?

    var body: some View {
        NavigationView {
            TrackList(tracks: tracks)
                .navigationTitle("Поиск")
                .searchable(text: $query)
                .onSubmit(of: .search) { Task { await search() } }
                .overlay {
                    if let error { Text(error).foregroundColor(.red).padding() }
                }
        }
        .navigationViewStyle(.stack)
    }

    func search() async {
        error = nil
        do { tracks = try await SC.search(query) }
        catch { self.error = error.localizedDescription }
    }
}

struct PlaylistsTab: View {
    @EnvironmentObject var library: Library

    var body: some View {
        NavigationView {
            List(library.playlists) { p in
                NavigationLink(destination: PlaylistDetail(playlist: p)) { PlaylistRow(playlist: p) }
            }
            .listStyle(.plain)
            .navigationTitle(library.user?.username ?? "Плейлисты")
            .refreshable { await library.load() }
            .overlay(StatusOverlay(empty: library.playlists.isEmpty))
            .modifier(PlayerInset())
        }
        .navigationViewStyle(.stack)
    }
}

struct LikesTab: View {
    @EnvironmentObject var library: Library

    var body: some View {
        NavigationView {
            TrackList(tracks: library.likes)
                .navigationTitle("Лайки")
                .refreshable { await library.load() }
                .overlay(StatusOverlay(empty: library.likes.isEmpty))
        }
        .navigationViewStyle(.stack)
    }
}

struct SettingsTab: View {
    @EnvironmentObject var library: Library
    @AppStorage("profile") private var profile = ""
    @AppStorage("oauth_token") private var token = ""
    @AppStorage("client_id") private var clientID = "yNSW5UvBmb1A5j7qPUtIMuB9Itx3jsOC"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Профиль"),
                        footer: Text("Ссылка или ник, например soundcloud.com/ник. Покажет публичные плейлисты и лайки.")) {
                    TextField("soundcloud.com/ник", text: $profile)
                        .autocapitalization(.none).disableAutocorrection(true)
                }
                Section(header: Text("Токен (необязательно)"),
                        footer: Text("oauth_token из браузера. Открывает приватные плейлисты. Никому его не показывай.")) {
                    SecureField("oauth_token", text: $token)
                }
                Section(header: Text("client_id")) {
                    TextField("client_id", text: $clientID)
                        .autocapitalization(.none).disableAutocorrection(true)
                }
                Section {
                    Button("Сохранить и обновить") { Task { await library.load() } }
                    if let u = library.user { Text("Аккаунт: \(u.username)").foregroundColor(.secondary) }
                    if let e = library.error { Text(e).foregroundColor(.red) }
                }
            }
            .navigationTitle("Настройки")
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Components

struct PlaylistDetail: View {
    let playlist: Playlist
    @State private var tracks: [Track] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        TrackList(tracks: tracks)
            .navigationTitle(playlist.title)
            .overlay {
                if loading { ProgressView() }
                else if let error { Text(error).foregroundColor(.red).padding() }
            }
            .task {
                do { tracks = try await SC.tracks(of: playlist) }
                catch { self.error = error.localizedDescription }
                loading = false
            }
    }
}

struct TrackList: View {
    @EnvironmentObject var player: Player
    let tracks: [Track]

    var body: some View {
        List(tracks) { t in
            Button { Task { await player.play(t, in: tracks) } } label: { TrackRow(track: t) }
        }
        .listStyle(.plain)
        .modifier(PlayerInset())
    }
}

struct StatusOverlay: View {
    @EnvironmentObject var library: Library
    let empty: Bool

    var body: some View {
        if library.loading && empty {
            ProgressView()
        } else if let e = library.error, empty {
            Text(e).multilineTextAlignment(.center).foregroundColor(.secondary).padding()
        } else if empty {
            Text("Пусто").foregroundColor(.secondary)
        }
    }
}

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: playlist.artwork_url.flatMap { URL(string: $0) }) { $0.resizable() } placeholder: { Color.gray.opacity(0.3) }
                .frame(width: 52, height: 52).cornerRadius(6)
            VStack(alignment: .leading) {
                Text(playlist.title).lineLimit(1)
                Text("\(playlist.track_count ?? 0) треков").font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { $0.resizable() } placeholder: { Color.gray.opacity(0.3) }
                .frame(width: 52, height: 52).cornerRadius(6)
            VStack(alignment: .leading) {
                Text(track.title).lineLimit(1).foregroundColor(.primary)
                Text(track.user.username).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

struct PlayerInset: ViewModifier {
    @EnvironmentObject var player: Player

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if player.current != nil { MiniPlayer() }
        }
    }
}

struct MiniPlayer: View {
    @EnvironmentObject var player: Player

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading) {
                Text(player.current?.title ?? "").lineLimit(1)
                Text(player.current?.user.username ?? "").font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Button { Task { await player.previous() } } label: { Image(systemName: "backward.fill") }
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title2)
            }
            Button { Task { await player.next() } } label: { Image(systemName: "forward.fill") }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
