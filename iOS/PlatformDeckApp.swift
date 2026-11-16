import SwiftUI

@main
struct PlatformDeckApp: App {
    @State private var store = DeckStore()
    static func initialTab() -> Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count { return Int(args[i + 1]) ?? 0 }
        return 0
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(deckAccent)
                .environment(store)
        }
    }
}

/// Sidebar sections of the iPad split view.
enum PadSection: Hashable, CaseIterable {
    case today, browse, favorites, settings
    var title: String {
        switch self { case .today: "Today"; case .browse: "Browse"; case .favorites: "Favorites"; case .settings: "Settings" }
    }
    var icon: String {
        switch self { case .today: "sun.max"; case .browse: "square.grid.2x2"; case .favorites: "star"; case .settings: "gearshape" }
    }
}

/// iPad (regular width) gets a NavigationSplitView; iPhone and compact multitasking keep the TabView.
struct RootView: View {
    @Environment(DeckStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var tab = PlatformDeckApp.initialTab()
    @State private var section: PadSection = .today
    @State private var path = NavigationPath()
    @State private var browsePath = NavigationPath()
    @State private var detailPath = NavigationPath()

    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                List {
                    ForEach(PadSection.allCases, id: \.self) { s in
                        Button { section = s } label: {
                            Label(s.title, systemImage: s.icon)
                                .foregroundStyle(section == s ? deckAccent : .primary)
                        }
                        .accessibilityIdentifier("sidebar-\(s)")
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("Deck")
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            } detail: {
                NavigationStack(path: $detailPath) {
                    Group {
                        switch section {
                        case .today: TodayView()
                        case .browse: BrowseView()
                        case .favorites: FavoritesView()
                        case .settings: SettingsView()
                        }
                    }
                    .deckDestinations()
                }
            }
            .onChange(of: section) { detailPath = NavigationPath() }
            .onAppear { for r in LaunchArgs.initialPath(store) { detailPath.appendAny(r) } }
        } else {
            TabView(selection: $tab) {
                NavigationStack(path: $path) { TodayView().deckDestinations() }
                    .tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
                NavigationStack(path: $browsePath) { BrowseView().deckDestinations() }
                    .tabItem { Label("Browse", systemImage: "square.grid.2x2") }.tag(1)
                NavigationStack { FavoritesView().deckDestinations() }
                    .tabItem { Label("Favorites", systemImage: "star") }.tag(2)
                NavigationStack { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
            }
            .onAppear { for r in LaunchArgs.initialPath(store) { if tab == 1 { browsePath.appendAny(r) } else { path.appendAny(r) } } }
        }
    }
}

struct BrowseView: View {
    @Environment(DeckStore.self) private var store
    @State private var query = LaunchArgs.value("-search") ?? ""
    var body: some View {
        List {
            if query.isEmpty {
                ForEach(store.categories, id: \.self) { c in
                    NavigationLink(value: Route.category(c)) { CategoryRow(category: c) }
                }
            } else {
                ForEach(store.search(query)) { g in NavigationLink(value: g) { GuideRow(guide: g) } }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(store.guides.count) cards")
        .navigationTitle("Browse")
    }
}

struct FavoritesView: View {
    @Environment(DeckStore.self) private var store
    var body: some View { GuideListView(title: "Favorites", guides: store.favoriteGuides) }
}
