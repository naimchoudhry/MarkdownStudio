import AppKit
import Observation

/// Which panes a document tab shows. Each tab (window) has its own, so hiding the Markdown pane
/// in one tab leaves the others as they are.
@Observable
final class PaneLayout {
    var isMarkdownPaneVisible = true
    /// Only Markdown files have a rendered pane to fall back on; other text files always show their source.
    @ObservationIgnored var canHideMarkdownPane = true

    @ObservationIgnored weak var window: NSWindow?
    /// The Markdown pane's share of the split's width: a third when a document opens (the rendered pane
    /// gets two thirds), then whatever it was when the pane was hidden, restored when it's shown.
    @ObservationIgnored private var markdownFraction = 1.0 / 3

    func toggleMarkdownPane() {
        guard canHideMarkdownPane else { return }
        if isMarkdownPaneVisible, let split = splitView, let pane = split.arrangedSubviews.first, split.bounds.width > 0 {
            markdownFraction = pane.frame.width / split.bounds.width
        }
        isMarkdownPaneVisible.toggle()
    }

    /// The split view comes back with the Markdown pane at its minimum width; put the divider back.
    @discardableResult
    func restoreDividerPosition() -> Bool {
        guard let split = splitView, split.arrangedSubviews.count == 2, split.bounds.width > 0 else { return false }
        split.setPosition((split.bounds.width - split.dividerThickness) * markdownFraction, ofDividerAt: 0)
        return true
    }

    /// Splits a newly opened Markdown document a third / two thirds, once its window is laid out.
    func applyInitialSplit() {
        Task {
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(50))
                if restoreDividerPosition() { return }
            }
        }
    }

    private var splitView: NSSplitView? {
        func find(in view: NSView?) -> NSSplitView? {
            guard let view else { return nil }
            if let split = view as? NSSplitView, split.isVertical { return split }
            return view.subviews.lazy.compactMap { find(in: $0) }.first
        }
        return find(in: window?.contentView)
    }
}
