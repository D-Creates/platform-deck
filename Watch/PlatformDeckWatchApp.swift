import SwiftUI

@main
struct PlatformDeckWatchApp: App {
    @State private var store = DeckStore()
    @State private var path = NavigationPath()
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) { WatchHome().deckDestinations() }.environment(store)
                .onAppear { LaunchArgs.initialPath(store).forEach { path.appendAny($0) } }
        }
    }
}

struct WatchHome: View {
    @Environment(DeckStore.self) private var store
    var body: some View {
        List {
            if let pick = store.dailyPick() {
                NavigationLink(value: pick) {
                    VStack(alignment: .leading) {
                        Text("Today").font(.caption2).foregroundStyle(deckAccent)
                        Text(pick.displayTitle).font(.headline)
                    }
                }.accessibilityIdentifier("daily-pick")
            }
            NavigationLink(value: Route.quiz) { Label("Quiz", systemImage: "questionmark.circle") }.accessibilityIdentifier("start-quiz-or-link")
            NavigationLink { GuideListView(title: "Favorites", guides: store.favoriteGuides) } label: {
                Label("Favorites (\(store.favorites.count))", systemImage: "star")
            }
            Section("Categories") {
                ForEach(store.categories, id: \.self) { c in
                    NavigationLink(value: Route.category(c)) { Label(Categories.label(c), systemImage: Categories.symbol(c)) }.accessibilityIdentifier("category-\(c)")
                }
            }
            Section {
                Gauge(value: store.progress) { Text("Learned") } currentValueLabel: { Text("\(store.learned.count)") }
                    .gaugeStyle(.accessoryLinearCapacity).tint(.green)
                NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }.accessibilityIdentifier("settings-link")
            }
        }
        .navigationTitle("Platform Deck")
    }
}
