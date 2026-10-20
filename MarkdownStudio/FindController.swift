import AppKit
import Observation
import SwiftUI

nonisolated enum FindMode: String, CaseIterable, Identifiable, Codable {
    case contains
    case startsWith
    case wholeWord
    case endsWith

    var id: Self { self }

    var title: String {
        switch self {
        case .contains: "Contains"
        case .startsWith: "Starts With"
        case .wholeWord: "Whole Word"
        case .endsWith: "Ends With"
        }
    }
}

/// A search request. The same rules are implemented in Swift (source pane) and `editor.js` (rendered pane).
nonisolated struct FindSearch: Equatable, Codable {
    var query: String
    var isRegex: Bool
    var matchCase: Bool
    var mode: FindMode

    func regularExpression() throws -> NSRegularExpression {
        var pattern = isRegex ? query : NSRegularExpression.escapedPattern(for: query)
        let word = #"[\p{L}\p{N}_]"#
        if mode == .startsWith || mode == .wholeWord { pattern = "(?<!\(word))(?:\(pattern))" }
        if mode == .endsWith || mode == .wholeWord { pattern = "(?:\(pattern))(?!\(word))" }
        return try NSRegularExpression(pattern: pattern, options: matchCase ? [] : [.caseInsensitive])
    }

    /// The replacement template for `NSRegularExpression`: literal text, or `$1`-style references
    /// (with JavaScript's `$&` accepted as an alias for `$0`).
    func replacementTemplate(for replacement: String) -> String {
        isRegex
            ? replacement.replacingOccurrences(of: "$&", with: "$0")
            : NSRegularExpression.escapedTemplate(for: replacement)
    }
}

nonisolated struct FindResult: Equatable, Decodable {
    var count = 0
    /// Index of the current match, or -1.
    var current = -1
    var error: String?
    var replaced: Int?
}

/// A pane that can be searched: the source text view or the rendered web view.
protocol FindEngine: AnyObject {
    func find(_ search: FindSearch?) async -> FindResult
    func selectMatch(at index: Int) async
    func replaceMatch(at index: Int, with replacement: String) async -> FindResult
    func replaceAll(with replacement: String) async -> FindResult
    func selectedText() async -> String
    /// Puts keyboard focus back in the pane, e.g. when the find bar closes.
    func focusPane()
}

/// Drives the find bar for one document window.
@Observable
final class FindController {
    enum Target: String, CaseIterable, Identifiable {
        case markdown
        case rendered

        var id: Self { self }
        var title: String { self == .markdown ? "Markdown" : "Rendered" }
    }

    var isVisible = false
    var showsReplace = false
    var query = "" { didSet { if query != oldValue { search() } } }
    var replacement = ""
    var matchCase = false { didSet { if matchCase != oldValue { search() } } }
    var useRegex = false { didSet { if useRegex != oldValue { search() } } }
    var mode = FindMode.contains { didSet { if mode != oldValue { search() } } }
    var wrapsAround = true
    var target = Target.markdown {
        didSet {
            guard target != oldValue else { return }
            Task { _ = await engine(for: oldValue)?.find(nil) }
            search()
        }
    }

    private(set) var matchCount = 0
    private(set) var currentIndex: Int?
    private(set) var errorMessage: String?
    private(set) var statusMessage: String?
    /// Incremented to ask the find bar to focus its search field.
    private(set) var focusRequest = 0

    @ObservationIgnored weak var markdownEngine: FindEngine?
    @ObservationIgnored weak var renderedEngine: FindEngine?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    private var currentSearch: FindSearch? {
        guard isVisible, !query.isEmpty else { return nil }
        return FindSearch(query: query, isRegex: useRegex, matchCase: matchCase, mode: mode)
    }

    private func engine(for target: Target) -> FindEngine? {
        target == .markdown ? markdownEngine : renderedEngine
    }

    private var activeEngine: FindEngine? { engine(for: target) }

    // MARK: Showing and hiding

    func show(replace: Bool) {
        if replace { showsReplace = true }
        let wasVisible = isVisible
        isVisible = true
        focusRequest += 1
        if !wasVisible { search() }
    }

    /// ⌘F: shows the find bar, or hides it if it's already showing.
    func toggle() {
        if isVisible { close() } else { show(replace: false) }
    }

    /// ⌥⌘F: shows find and replace, or hides the bar if the replace field is already showing.
    func toggleReplace() {
        if isVisible && showsReplace { close() } else { show(replace: true) }
    }

    func close() {
        if isVisible { activeEngine?.focusPane() }
        isVisible = false
        searchTask?.cancel()
        statusMessage = nil
        Task {
            _ = await markdownEngine?.find(nil)
            _ = await renderedEngine?.find(nil)
        }
    }

    /// Called when a pane gains focus, so searches apply to the pane being edited.
    func paneDidBecomeActive(_ pane: Target) {
        target = pane
    }

    // MARK: Searching

    func search() {
        searchTask?.cancel()
        statusMessage = nil
        let search = currentSearch
        let engine = activeEngine
        searchTask = Task {
            guard let result = await engine?.find(search), !Task.isCancelled else { return }
            apply(result)
        }
    }

    /// Called by an engine when its content changed and it re-ran the active search.
    func engine(_ engine: FindEngine, didUpdate result: FindResult) {
        guard isVisible, engine === activeEngine else { return }
        apply(result)
    }

    private func apply(_ result: FindResult) {
        matchCount = result.count
        currentIndex = result.current >= 0 ? result.current : nil
        errorMessage = result.error
    }

    func findNext() {
        move(by: 1)
    }

    func findPrevious() {
        move(by: -1)
    }

    private func move(by step: Int) {
        if !isVisible { show(replace: false); return }
        guard matchCount > 0, let engine = activeEngine else { NSSound.beep(); return }
        var index = (currentIndex ?? (step > 0 ? -1 : matchCount)) + step
        if index < 0 || index >= matchCount {
            guard wrapsAround else { NSSound.beep(); return }
            index = (index + matchCount) % matchCount
        }
        currentIndex = index
        statusMessage = nil
        Task { await engine.selectMatch(at: index) }
    }

    func replaceCurrent() {
        guard let index = currentIndex, let search = currentSearch, let engine = activeEngine else { NSSound.beep(); return }
        let template = search.replacementTemplate(for: replacement)
        let raw = replacement
        Task {
            let result = await engine.replaceMatch(at: index, with: target == .markdown ? template : raw)
            apply(result)
            statusMessage = nil
        }
    }

    func replaceAll() {
        guard matchCount > 0, let search = currentSearch, let engine = activeEngine else { NSSound.beep(); return }
        let template = search.replacementTemplate(for: replacement)
        let raw = replacement
        Task {
            let result = await engine.replaceAll(with: target == .markdown ? template : raw)
            apply(result)
            let replaced = result.replaced ?? 0
            statusMessage = replaced == 1 ? "Replaced 1 match" : "Replaced \(replaced) matches"
        }
    }

    func useSelectionForFind() {
        guard let engine = activeEngine else { return }
        Task {
            let text = await engine.selectedText()
            guard !text.isEmpty else { NSSound.beep(); return }
            isVisible = true
            query = text
        }
    }
}
