import Observation
import SwiftUI

/// A pane whose scroll position can be expressed as a (fractional) source line number.
protocol LineScrollable: AnyObject {
    func currentLine() async -> Double
    func scroll(toLine line: Double)
}

/// Keeps the Markdown and rendered panes aligned while scrolling, when linked.
@Observable
final class ScrollSync {
    enum Pane: String, CaseIterable, Identifiable {
        case markdown
        case rendered

        var id: Self { self }
        var title: String { self == .markdown ? "Markdown" : "Rendered" }
    }

    private static let linkedKey = "ScrollSyncLinked"
    private static let anchorKey = "ScrollSyncAnchor"

    /// When on, scrolling either pane scrolls the other to the matching position.
    var isLinked = UserDefaults.standard.bool(forKey: linkedKey) {
        didSet {
            UserDefaults.standard.set(isLinked, forKey: Self.linkedKey)
            if isLinked && !oldValue { align() }
        }
    }

    /// The pane the other one snaps to when linking is turned on.
    var anchor = Pane(rawValue: UserDefaults.standard.string(forKey: anchorKey) ?? "") ?? .markdown {
        didSet { UserDefaults.standard.set(anchor.rawValue, forKey: Self.anchorKey) }
    }

    @ObservationIgnored weak var markdownPane: LineScrollable?
    @ObservationIgnored weak var renderedPane: LineScrollable?

    func toggle() {
        isLinked.toggle()
    }

    /// Scrolls the other pane to match `pane` (by default, the chosen anchor) once.
    func align(to pane: Pane? = nil) {
        let leader = pane ?? anchor
        let (source, follower) = leader == .markdown ? (markdownPane, renderedPane) : (renderedPane, markdownPane)
        guard let source, let follower else { return }
        self.leader = leader
        leaderUntil = ContinuousClock.now + Self.leaderHold
        Task {
            let line = await source.currentLine()
            follower.scroll(toLine: line)
        }
    }

    /// The pane the user is currently scrolling. Scroll reports from the other pane are echoes of
    /// our own programmatic scrolling until the leader has been still for a moment.
    @ObservationIgnored private var leader: Pane?
    @ObservationIgnored private var leaderUntil = ContinuousClock.now
    private static let leaderHold = Duration.milliseconds(300)

    func pane(_ pane: Pane, didScrollTo line: Double) {
        guard isLinked else { return }
        let now = ContinuousClock.now
        if let leader, leader != pane, now < leaderUntil { return }
        leader = pane
        leaderUntil = now + Self.leaderHold
        (pane == .markdown ? renderedPane : markdownPane)?.scroll(toLine: line)
    }

    /// The rendered pane re-renders after source edits; keep it aligned with the source being edited.
    func renderedPaneDidReload() {
        guard isLinked else { return }
        align(to: .markdown)
    }
}
