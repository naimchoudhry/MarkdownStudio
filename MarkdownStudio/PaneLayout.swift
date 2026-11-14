import AppKit
import Observation

/// Which panes a document tab shows. Each tab (window) has its own, so hiding the Markdown pane
/// in one tab leaves the others as they are.
@Observable
final class PaneLayout {
    var isMarkdownPaneVisible = true

    @ObservationIgnored weak var window: NSWindow?
    /// The Markdown pane's share of the split's width when it was hidden, restored when it's shown.
    @ObservationIgnored private var markdownFraction = 0.5

    func toggleMarkdownPane() {
        if isMarkdownPaneVisible, let split = splitView, let pane = split.arrangedSubviews.first, split.bounds.width > 0 {
            markdownFraction = pane.frame.width / split.bounds.width
        }
        isMarkdownPaneVisible.toggle()
    }

    /// The split view comes back with the Markdown pane at its minimum width; put the divider back.
    func restoreDividerPosition() {
        guard let split = splitView, split.arrangedSubviews.count == 2 else { return }
        split.setPosition((split.bounds.width - split.dividerThickness) * markdownFraction, ofDividerAt: 0)
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
