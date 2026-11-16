import SwiftUI

let deckAccent = Color(red: 0.16, green: 0.45, blue: 0.95)

struct CategoryRow: View {
    @Environment(DeckStore.self) private var store
    let category: String
    var body: some View {
        HStack {
            Label(Categories.label(category), systemImage: Categories.symbol(category))
            Spacer()
            Text("\(store.guides(in: category).count)").foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityIdentifier("category-\(category)")
    }
}

struct GuideRow: View {
    @Environment(DeckStore.self) private var store
    let guide: Guide
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(guide.displayTitle).font(.headline)
                if store.favorites.contains(guide.id) { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                if store.learned.contains(guide.id) { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.caption) }
            }
            Text(guide.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("guide-\(guide.id)")
    }
}

struct GuideListView: View {
    @Environment(DeckStore.self) private var store
    let title: String
    let guides: [Guide]
    var body: some View {
        List(guides) { g in
            NavigationLink(value: g) { GuideRow(guide: g) }
        }
        .navigationTitle(title)
        .overlay { if guides.isEmpty { ContentUnavailableView("No cards", systemImage: "rectangle.stack") } }
    }
}

struct GuideDetailView: View {
    @Environment(DeckStore.self) private var store
    let guide: Guide
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(Categories.label(guide.category), systemImage: Categories.symbol(guide.category))
                    .font(.caption.weight(.semibold)).foregroundStyle(deckAccent)
                Text(guide.displayTitle).font(.largeTitle.bold()).accessibilityIdentifier("detail-title")
                Text(guide.summary).font(.title3)
                #if !os(watchOS)
                if !guide.intro.isEmpty {
                    Text(.init(guide.intro)).font(.body).foregroundStyle(.secondary)
                }
                #endif
                if !guide.features.isEmpty {
                    Text("Platform features").font(.headline)
                    FlowTags(tags: guide.features)
                }
                HStack {
                    Button {
                        store.toggleFavorite(guide)
                    } label: {
                        Label(store.favorites.contains(guide.id) ? "Unfavorite" : "Favorite",
                              systemImage: store.favorites.contains(guide.id) ? "star.fill" : "star")
                    }
                    .buttonStyle(.bordered).accessibilityIdentifier("favorite-button")
                    Button {
                        store.toggleLearned(guide)
                    } label: {
                        Label(store.learned.contains(guide.id) ? "Learned" : "Mark learned",
                              systemImage: store.learned.contains(guide.id) ? "checkmark.seal.fill" : "checkmark.seal")
                    }
                    .buttonStyle(.borderedProminent).tint(deckAccent).accessibilityIdentifier("learned-button")
                }
                ShareLink(item: "\(guide.displayTitle): \(guide.summary)") { Label("Share card", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("share-button")
                Text("Card text adapted from Apache-2.0 open-source guides. See About.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle(guide.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct FlowTags: View {
    let tags: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(tags, id: \.self) { t in
                    Text(t).font(.caption.monospaced()).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(deckAccent.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}

struct TodayView: View {
    @Environment(DeckStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let pick = store.dailyPick() {
                    Text("Card of the day").font(.headline).foregroundStyle(.secondary)
                    DeckLink(value: pick) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(Categories.label(pick.category), systemImage: Categories.symbol(pick.category)).font(.caption)
                            Text(pick.displayTitle).font(.title2.bold())
                            Text(pick.summary).font(.body)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [deckAccent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("daily-pick")
                }
                ProgressCard()
                DeckLink(value: Route.quiz) {
                    Label("Start a 5-question quiz", systemImage: "questionmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(deckAccent).controlSize(.large)
                .accessibilityIdentifier("start-quiz-or-link")
            }
            .padding()
        }
        .navigationTitle("Today")
    }
}

struct ProgressCard: View {
    @Environment(DeckStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your progress").font(.headline)
            ProgressView(value: store.progress).tint(.green)
            Text("\(store.learned.count) of \(store.guides.count) cards learned · \(store.favorites.count) favorites · best quiz \(store.bestQuiz)/5")
                .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("progress-text")
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}

enum Route: Hashable { case quiz, category(String) }

struct QuizView: View {
    @Environment(DeckStore.self) private var store
    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var score = 0
    @State private var chosen: String?

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            if questions.isEmpty {
                ProgressView()
            } else if index >= questions.count {
                VStack(spacing: 16) {
                    Image(systemName: score >= 4 ? "trophy.fill" : "checkmark.circle").font(.system(size: 60)).foregroundStyle(deckAccent)
                    Text("Score \(score)/\(questions.count)").font(.largeTitle.bold()).accessibilityIdentifier("quiz-score")
                    Button("Play again") { restart() }.buttonStyle(.borderedProminent).accessibilityIdentifier("quiz-again")
                }
                .frame(maxWidth: .infinity)
            } else {
                let q = questions[index]
                Text("Question \(index + 1) of \(questions.count)").font(.caption).foregroundStyle(.secondary)
                Text("Which card matches this description?").font(.headline)
                Text(q.answer.summary).font(.title3).accessibilityIdentifier("quiz-prompt")
                ForEach(Array(q.options.enumerated()), id: \.element.id) { i, opt in
                    Button {
                        guard chosen == nil else { return }
                        chosen = opt.id
                        if opt.id == q.answer.id { score += 1 }
                    } label: {
                        HStack {
                            Text(opt.displayTitle).multilineTextAlignment(.leading)
                            Spacer()
                            if let c = chosen {
                                if opt.id == q.answer.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                else if opt.id == c { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
                            }
                        }
                        .padding().frame(maxWidth: .infinity)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("quiz-option-\(i)")
                }
                if chosen != nil {
                    Button(index + 1 == questions.count ? "See score" : "Next") {
                        chosen = nil; index += 1
                        if index == questions.count { store.bestQuiz = max(store.bestQuiz, score) }
                    }
                    .buttonStyle(.borderedProminent).tint(deckAccent).accessibilityIdentifier("quiz-next")
                }
            }
        }
        .padding()
        }
        .navigationTitle("Quiz")
        .onAppear { if questions.isEmpty { restart() } }
    }

    private func restart() { questions = store.makeQuiz(); index = 0; score = 0; chosen = nil }
}

struct SettingsView: View {
    @Environment(DeckStore.self) private var store
    @State private var confirm = false
    var body: some View {
        Form {
            Section("Progress") {
                ProgressCard()
                Button("Reset progress and favorites", role: .destructive) { confirm = true }
                    .accessibilityIdentifier("reset-button")
            }
            Section("About") {
                Text("Platform Deck is an offline flash-card companion for modern web platform techniques. No account, no tracking, no network access.")
                Text("Card text is adapted from open-source guides published under the Apache License 2.0. This app is not affiliated with or endorsed by the authors of those guides.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Version 1.0 · \(store.guides.count) cards").font(.footnote).accessibilityIdentifier("about-version")
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Reset everything?", isPresented: $confirm) {
            Button("Reset", role: .destructive) { store.resetAll() }.accessibilityIdentifier("confirm-reset")
        }
    }
}

extension View {
    func deckDestinations() -> some View {
        self.navigationDestination(for: Guide.self) { GuideDetailView(guide: $0) }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .quiz: QuizView()
                case .category(let c): CategoryGuidesView(category: c)
                }
            }
    }
}

struct CategoryGuidesView: View {
    @Environment(DeckStore.self) private var store
    let category: String
    var body: some View { GuideListView(title: Categories.label(category), guides: store.guides(in: category)) }
}

/// On macOS, links inside a ScrollView in the split-view detail don't push; the Mac root
/// injects a navigate action so these become plain buttons that append to its path.
extension EnvironmentValues {
    @Entry var deckNavigate: (@MainActor (AnyHashable) -> Void)? = nil
}

struct DeckLink<Label: View>: View {
    @Environment(\.deckNavigate) private var navigate
    let value: AnyHashable
    @ViewBuilder let label: () -> Label
    var body: some View {
        if let navigate {
            Button { navigate(value) } label: { label() }
        } else if let g = value.base as? Guide {
            NavigationLink(value: g) { label() }
        } else if let r = value.base as? Route {
            NavigationLink(value: r) { label() }
        }
    }
}
