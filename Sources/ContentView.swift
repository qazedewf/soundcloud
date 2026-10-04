import SwiftUI

struct ContentView: View {
    @StateObject private var player = Player()
    @AppStorage("client_id") private var clientID = "yNSW5UvBmb1A5j7qPUtIMuB9Itx3jsOC"
    @State private var query = ""
    @State private var tracks: [Track] = []
    @State private var error: String?
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            List(tracks) { t in
                Button { Task { await player.play(t) } } label: { TrackRow(track: t) }
            }
            .listStyle(.plain)
            .navigationTitle("SoundCloud")
            .searchable(text: $query)
            .onSubmit(of: .search) { Task { await search() } }
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gear") }
            }
            .safeAreaInset(edge: .bottom) {
                if player.current != nil { MiniPlayer(player: player) }
            }
            .overlay {
                if let error { Text(error).foregroundColor(.red).padding() }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                Form {
                    Section(header: Text("client_id")) {
                        TextField("client_id", text: $clientID)
                            .autocapitalization(.none).disableAutocorrection(true)
                    }
                }
                .navigationTitle("Настройки")
                .toolbar { Button("Готово") { showSettings = false } }
            }
        }
    }

    func search() async {
        error = nil
        do { tracks = try await SC.search(query) }
        catch { self.error = "Ошибка: \(error.localizedDescription)\nПроверь client_id" }
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

struct MiniPlayer: View {
    @ObservedObject var player: Player
    var body: some View {
        HStack {
            Text(player.current?.title ?? "").lineLimit(1)
            Spacer()
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
