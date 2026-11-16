import Foundation
import Observation

/// One flash card built from a guide summary (Apache-2.0 source, see NOTICE).
struct Guide: Codable, Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let summary: String
    let intro: String
    let features: [String]

    var displayTitle: String { title.isEmpty ? id.replacingOccurrences(of: "-", with: " ").capitalized : title }
}

enum Categories {
    static func label(_ key: String) -> String {
        switch key {
        case "ui-atoms": return "UI Atoms"
        case "ui-behaviors": return "UI Behaviors"
        case "ui-components": return "UI Components"
        case "built-in-ai": return "Built-in AI"
        case "css": return "CSS"
        case "html": return "HTML"
        case "js": return "JavaScript"
        case "pwa": return "Installable Apps"
        case "wasm": return "WebAssembly"
        case "webmcp": return "Agent Tools"
        default: return key.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
    static func symbol(_ key: String) -> String {
        switch key {
        case "accessibility": return "accessibility"
        case "built-in-ai": return "sparkles"
        case "css": return "paintbrush"
        case "forms": return "list.bullet.rectangle"
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "js": return "curlybraces"
        case "performance": return "gauge.with.dots.needle.67percent"
        case "privacy": return "hand.raised"
        case "pwa": return "app.badge"
        case "security": return "lock.shield"
        case "user-experience": return "person.crop.circle"
        case "visual-design": return "swatchpalette"
        case "wasm": return "cpu"
        case "webmcp": return "wrench.and.screwdriver"
        default: return "square.grid.2x2"
        }
    }
}

struct QuizQuestion: Identifiable {
    let id = UUID()
    let answer: Guide
    let options: [Guide]
}

@Observable
final class DeckStore {
    let guides: [Guide]
    var favorites: Set<String> { didSet { save("favorites", favorites) } }
    var learned: Set<String> { didSet { save("learned", learned) } }
    var bestQuiz: Int { didSet { defaults.set(bestQuiz, forKey: "bestQuiz") } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        if defaults.bool(forKey: "UITestReset") || ProcessInfo.processInfo.arguments.contains("-resetData") {
            ["favorites", "learned", "bestQuiz"].forEach { defaults.removeObject(forKey: $0) }
        }
        if let url = bundle.url(forResource: "guides", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([Guide].self, from: data) {
            guides = list
        } else {
            guides = []
        }
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        learned = Set(defaults.stringArray(forKey: "learned") ?? [])
        bestQuiz = defaults.integer(forKey: "bestQuiz")
    }

    private func save(_ key: String, _ set: Set<String>) { defaults.set(Array(set).sorted(), forKey: key) }

    var categories: [String] { Array(Set(guides.map(\.category))).sorted() }
    func guides(in category: String) -> [Guide] { guides.filter { $0.category == category } }

    func search(_ text: String) -> [Guide] {
        let q = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return guides }
        return guides.filter {
            $0.displayTitle.lowercased().contains(q) || $0.summary.lowercased().contains(q)
                || $0.id.contains(q) || $0.features.contains { $0.contains(q) }
        }
    }

    func toggleFavorite(_ g: Guide) { if favorites.contains(g.id) { favorites.remove(g.id) } else { favorites.insert(g.id) } }
    func toggleLearned(_ g: Guide) { if learned.contains(g.id) { learned.remove(g.id) } else { learned.insert(g.id) } }

    var favoriteGuides: [Guide] { guides.filter { favorites.contains($0.id) } }
    var progress: Double { guides.isEmpty ? 0 : Double(learned.count) / Double(guides.count) }
    func progress(in category: String) -> Double {
        let list = guides(in: category)
        return list.isEmpty ? 0 : Double(list.filter { learned.contains($0.id) }.count) / Double(list.count)
    }

    /// Same pick for everyone on a given calendar day.
    func dailyPick(on date: Date = .now) -> Guide? {
        guard !guides.isEmpty else { return nil }
        let day = Calendar(identifier: .gregorian).ordinality(of: .day, in: .era, for: date) ?? 0
        return guides[day % guides.count]
    }

    func makeQuiz(count: Int = 5) -> [QuizQuestion] {
        guard guides.count >= 4 else { return [] }
        return guides.shuffled().prefix(count).map { answer in
            var opts = guides.filter { $0.id != answer.id }.shuffled().prefix(3).map { $0 }
            opts.append(answer)
            return QuizQuestion(answer: answer, options: opts.shuffled())
        }
    }

    func resetAll() { favorites = []; learned = []; bestQuiz = 0 }
}

enum SidebarItem: Hashable { case today, favorites, settings, category(String) }

/// macOS sidebar navigation. Every sidebar click — including a re-tap on the
/// already-selected row — goes through `select(_:)`, which clears the active
/// search; a selection-change callback alone would miss the re-tap case.
@Observable
final class SidebarNav {
    var selection: SidebarItem?
    var query: String
    var path = NavigationPath()

    init(selection: SidebarItem? = nil, query: String = "") {
        self.selection = selection
        self.query = query
    }

    func select(_ item: SidebarItem) {
        selection = item
        path = NavigationPath()
        query = ""
    }
}

/// Launch arguments used for screenshots and UI checks: -seed, -open <id>, -quiz, -category <key>, -search <text>.
enum LaunchArgs {
    static let args = ProcessInfo.processInfo.arguments
    static func value(_ k: String) -> String? {
        if let eq = args.first(where: { $0.hasPrefix(k + "=") }) { return String(eq.dropFirst(k.count + 1)) }
        return args.firstIndex(of: k).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
    }
    static func has(_ k: String) -> Bool { args.contains(k) }
    @MainActor static func initialPath(_ store: DeckStore) -> [AnyHashable] {
        if has("-seed") { store.guides.prefix(40).forEach { store.learned.insert($0.id) }; store.guides.dropFirst(3).prefix(6).forEach { store.favorites.insert($0.id) }; store.bestQuiz = 4 }
        var p: [AnyHashable] = []
        if let c = value("-category") { p.append(Route.category(c)) }
        if let id = value("-open"), let g = store.guides.first(where: { $0.id == id }) { p.append(g) }
        if has("-quiz") { p.append(Route.quiz) }
        return p
    }
}

import SwiftUI
extension NavigationPath {
    mutating func appendAny(_ v: AnyHashable) {
        if let r = v.base as? Route { append(r) } else if let g = v.base as? Guide { append(g) }
    }
}
