import SwiftUI

@main
struct PlatformDeckMacApp: App {
    @State private var store = DeckStore()
    var body: some Scene {
        Window("Platform Deck", id: "main") {
            MacRootView().environment(store).frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandMenu("Deck") {
                Button("Back") { NotificationCenter.default.post(name: .deckBack, object: nil) }
                    .keyboardShortcut("[", modifiers: .command)
                Button("Random Card") { NotificationCenter.default.post(name: .randomCard, object: nil) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let randomCard = Notification.Name("randomCard")
    static let deckBack = Notification.Name("deckBack")
}

struct MacRootView: View {
    static func initialSelection() -> SidebarItem {
        if let c = LaunchArgs.value("-category") { return .category(c) }
        if LaunchArgs.has("-favorites") { return .favorites }
        if LaunchArgs.has("-settings") { return .settings }
        return .today
    }
    @Environment(DeckStore.self) private var store
    @State private var nav = SidebarNav(selection: MacRootView.initialSelection(), query: LaunchArgs.value("-search") ?? "")
    var body: some View {
        NavigationSplitView {
            List(selection: $nav.selection) {
                Section {
                    Button { nav.select(.today) } label: { Label("Today", systemImage: "sun.max") }
                        .accessibilityIdentifier("sidebar-today")
                    Button { nav.select(.favorites) } label: { Label("Favorites", systemImage: "star") }
                        .accessibilityIdentifier("sidebar-favorites")
                    Button { nav.select(.settings) } label: { Label("Settings", systemImage: "gearshape") }
                        .accessibilityIdentifier("sidebar-settings")
                }
                Section("Categories") {
                    ForEach(store.categories, id: \.self) { c in
                        Button { nav.select(.category(c)) } label: { CategoryRow(category: c) }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            NavigationStack(path: $nav.path) {
                Group {
                    if !nav.query.isEmpty {
                        GuideListView(title: "Search", guides: store.search(nav.query))
                    } else {
                        switch nav.selection ?? .today {
                        case .today: TodayView()
                        case .favorites: GuideListView(title: "Favorites", guides: store.favoriteGuides)
                        case .settings: SettingsView().formStyle(.grouped)
                        case .category(let c): CategoryGuidesView(category: c)
                        }
                    }
                }
                .deckDestinations()
            }
        }
        .searchable(text: $nav.query, prompt: "Search cards")
        .environment(\.deckNavigate) { nav.path.appendAny($0) }
        // Search results replace the detail pane, so a sidebar pick must leave search or it would stay hidden.
        // Sidebar clicks call nav.select(_:) directly (clears the query even on a re-tap); this also covers
        // selection changes that do not come from a click (e.g. keyboard navigation).
        .onChange(of: nav.selection) { nav.path = NavigationPath(); nav.query = "" }
        .task {
            if LaunchArgs.has("-seed") { _ = LaunchArgs.initialPath(store) }
            if let id = LaunchArgs.value("-open"), let g = store.guides.first(where: { $0.id == id }) { nav.path.append(g) }
            if LaunchArgs.has("-quiz") { nav.path.append(Route.quiz) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .randomCard)) { _ in
            if let g = store.guides.randomElement() { nav.path.append(g) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deckBack)) { _ in
            if !nav.path.isEmpty { nav.path.removeLast() }
        }
    }
}
