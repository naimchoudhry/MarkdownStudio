import AppKit
import SwiftUI

/// Plain-text Markdown source editor backed by `NSTextView`.
struct SourceEditorView: NSViewRepresentable {
    @Binding var text: String
    var findController: FindController?
    var scrollSync: ScrollSync?
    var zoom = 1.0

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = SourceTextView.scrollableTextView()
        let textView = scrollView.documentView as! SourceTextView
        // TextKit 1 gives straightforward access to line geometry (scroll alignment) and temporary
        // attributes (find highlighting). Asking for the layout manager switches the view over.
        _ = textView.layoutManager
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: ViewZoom.baseSourceFontSize * zoom, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 16)
        textView.string = text
        scrollView.contentView.postsBoundsChangedNotifications = true

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.scrollView = scrollView
        coordinator.findController = findController
        coordinator.scrollSync = scrollSync
        findController?.markdownEngine = coordinator
        scrollSync?.markdownPane = coordinator
        textView.onBecomeFirstResponder = { [weak findController] in
            findController?.paneDidBecomeActive(.markdown)
        }
        coordinator.observeScrolling()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let fontSize = CGFloat(ViewZoom.baseSourceFontSize * zoom)
        if textView.font?.pointSize != fontSize {
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            textView.font = font
            textView.typingAttributes[.font] = font
        }
        context.coordinator.apply(text, to: textView)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.stopObservingScrolling()
    }

    final class SourceTextView: NSTextView {
        var onBecomeFirstResponder: (() -> Void)?

        override func becomeFirstResponder() -> Bool {
            let accepted = super.becomeFirstResponder()
            if accepted { onBecomeFirstResponder?() }
            return accepted
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        weak var findController: FindController?
        weak var scrollSync: ScrollSync?

        private var isApplyingExternalChange = false
        private var isScrollingProgrammatically = false
        private var scrollObserver: NSObjectProtocol?
        private var cachedLineStarts: [Int]?

        // Find state
        private var activeSearch: FindSearch?
        private var regex: NSRegularExpression?
        private var matches: [NSRange] = []
        private var currentMatch = -1

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            textContentDidChange()
            guard !isApplyingExternalChange, let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        /// Applies text that changed elsewhere (e.g. the rendered view) by replacing only the
        /// differing range, so the selection, scroll position and undo stack stay intact.
        func apply(_ newText: String, to textView: NSTextView) {
            isApplyingExternalChange = true
            defer { isApplyingExternalChange = false }
            applyDifference(newText, to: textView)
        }

        fileprivate func applyDifference(_ newText: String, to textView: NSTextView) {
            let current = textView.string as NSString
            let updated = newText as NSString
            guard !current.isEqual(to: newText) else { return }

            var prefix = 0
            let maxPrefix = min(current.length, updated.length)
            while prefix < maxPrefix, current.character(at: prefix) == updated.character(at: prefix) {
                prefix += 1
            }
            var suffix = 0
            let maxSuffix = min(current.length, updated.length) - prefix
            while suffix < maxSuffix,
                  current.character(at: current.length - 1 - suffix) == updated.character(at: updated.length - 1 - suffix) {
                suffix += 1
            }

            let range = NSRange(location: prefix, length: current.length - prefix - suffix)
            let replacement = updated.substring(with: NSRange(location: prefix, length: updated.length - prefix - suffix))
            replace(range, with: replacement, in: textView)
        }

        /// An undoable edit that notifies the delegate (and so updates the document) as usual.
        fileprivate func replace(_ range: NSRange, with replacement: String, in textView: NSTextView) {
            guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
            textView.textStorage?.replaceCharacters(
                in: range,
                with: NSAttributedString(string: replacement, attributes: textView.typingAttributes)
            )
            textView.didChangeText()
        }

        private func textContentDidChange() {
            cachedLineStarts = nil
            guard activeSearch != nil else { return }
            runSearch(keepingIndex: currentMatch)
            findController?.engine(self, didUpdate: result())
        }

        // MARK: Scrolling

        func observeScrolling() {
            guard let clipView = scrollView?.contentView else { return }
            // No queue: the block runs synchronously as the clip view scrolls (always on the main
            // thread), so programmatic scrolls can be told apart from the user's.
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification, object: clipView, queue: nil
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.didScroll() }
            }
        }

        func stopObservingScrolling() {
            if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
            scrollObserver = nil
        }

        private func didScroll() {
            guard !isScrollingProgrammatically, let scrollSync, scrollSync.isLinked else { return }
            scrollSync.pane(.markdown, didScrollTo: topLine)
        }

        /// Character offsets at which each source line starts.
        private var lineStarts: [Int] {
            if let cachedLineStarts { return cachedLineStarts }
            let string = (textView?.string ?? "") as NSString
            var starts = [0]
            for index in 0..<string.length where string.character(at: index) == 0x0A {
                starts.append(index + 1)
            }
            cachedLineStarts = starts
            return starts
        }

        private func lineNumber(atCharacter index: Int) -> Int {
            let starts = lineStarts
            var low = 0
            var high = starts.count - 1
            while low < high {
                let mid = (low + high + 1) / 2
                if starts[mid] <= index { low = mid } else { high = mid - 1 }
            }
            return low
        }

        /// The rect of a whole source line (all of its wrapped fragments), in text container coordinates.
        private func rectForLine(_ line: Int) -> NSRect? {
            guard let textView, let layoutManager = textView.layoutManager, let container = textView.textContainer else { return nil }
            let string = textView.string as NSString
            let starts = lineStarts
            guard line < starts.count else { return nil }
            if starts[line] >= string.length {
                return layoutManager.extraLineFragmentRect.isEmpty ? nil : layoutManager.extraLineFragmentRect
            }
            let lineRange = string.lineRange(for: NSRange(location: starts[line], length: 0))
            let glyphs = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            return layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
        }

        /// The source line (with fraction) at the top of the visible area.
        var topLine: Double {
            guard let textView, let layoutManager = textView.layoutManager,
                  let container = textView.textContainer, !textView.string.isEmpty else { return 0 }
            // Work in the text view's own coordinates, independent of where its frame sits in the clip view.
            let y = textView.visibleRect.minY - textView.textContainerOrigin.y
            guard y > 0 else { return 0 }
            let length = (textView.string as NSString).length
            let glyph = layoutManager.glyphIndex(for: NSPoint(x: 0, y: y), in: container)
            let character = min(layoutManager.characterIndexForGlyph(at: glyph), length - 1)
            let line = lineNumber(atCharacter: character)
            guard let rect = rectForLine(line), rect.height > 0 else { return Double(line) }
            return Double(line) + min(max((y - rect.minY) / rect.height, 0), 1)
        }

        func scroll(toLine line: Double) {
            guard let textView, line.isFinite else { return }
            let index = max(Int(line.rounded(.down)), 0)
            let y: CGFloat
            if let rect = rectForLine(index) {
                y = rect.minY + CGFloat(line - Double(index)) * rect.height + textView.textContainerOrigin.y
            } else {
                y = textView.bounds.height
            }
            let maxY = max(textView.bounds.height - textView.visibleRect.height, 0)
            isScrollingProgrammatically = true
            textView.scroll(NSPoint(x: textView.visibleRect.minX, y: min(max(y, 0), maxY)))
            isScrollingProgrammatically = false
        }

        // MARK: Find

        private func result(error: String? = nil, replaced: Int? = nil) -> FindResult {
            FindResult(count: matches.count, current: currentMatch, error: error, replaced: replaced)
        }

        private func runSearch(keepingIndex preferred: Int? = nil) {
            guard let textView, let regex else {
                matches = []
                currentMatch = -1
                highlightMatches() // clears the highlights when the search ends
                return
            }
            let string = textView.string
            matches = regex.matches(in: string, range: NSRange(location: 0, length: (string as NSString).length))
                .map(\.range)
                .filter { $0.length > 0 }
            if matches.isEmpty {
                currentMatch = -1
            } else if let preferred, preferred >= 0 {
                currentMatch = min(preferred, matches.count - 1)
            } else {
                let caret = textView.selectedRange().location
                currentMatch = matches.firstIndex { $0.location >= caret } ?? 0
            }
            highlightMatches()
        }

        private func highlightMatches() {
            guard let textView, let layoutManager = textView.layoutManager else { return }
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            let color = NSColor.systemYellow.withAlphaComponent(0.35)
            for range in matches {
                layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
            }
            if matches.indices.contains(currentMatch) {
                layoutManager.addTemporaryAttribute(.backgroundColor, value: NSColor.systemYellow, forCharacterRange: matches[currentMatch])
            }
        }

        private func revealCurrentMatch() {
            guard let textView, matches.indices.contains(currentMatch) else { return }
            let range = matches[currentMatch]
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            textView.showFindIndicator(for: range)
        }
    }
}

extension SourceEditorView.Coordinator: FindEngine {
    func find(_ search: FindSearch?) async -> FindResult {
        activeSearch = search
        guard let search else {
            regex = nil
            runSearch()
            return result()
        }
        do {
            regex = try search.regularExpression()
        } catch {
            regex = nil
            runSearch()
            return result(error: "Invalid regular expression")
        }
        runSearch()
        revealCurrentMatch()
        return result()
    }

    func selectMatch(at index: Int) async {
        guard matches.indices.contains(index) else { return }
        currentMatch = index
        highlightMatches()
        revealCurrentMatch()
    }

    func replaceMatch(at index: Int, with template: String) async -> FindResult {
        guard let textView, let regex, matches.indices.contains(index) else { return result() }
        let range = matches[index]
        let string = textView.string
        guard let match = regex.firstMatch(in: string, range: range) else { return result() }
        let replacement = regex.replacementString(for: match, in: string, offset: 0, template: template)
        replace(range, with: replacement, in: textView)
        runSearch(keepingIndex: index)
        revealCurrentMatch()
        return result()
    }

    func replaceAll(with template: String) async -> FindResult {
        guard let textView, let regex, !matches.isEmpty else { return result(replaced: 0) }
        let string = textView.string
        let mutable = NSMutableString(string: string)
        let found = regex.matches(in: string, range: NSRange(location: 0, length: mutable.length)).filter { $0.range.length > 0 }
        for match in found.reversed() {
            let replacement = regex.replacementString(for: match, in: string, offset: 0, template: template)
            mutable.replaceCharacters(in: match.range, with: replacement)
        }
        // One undoable change covering just the edited span keeps the scroll position.
        applyDifference(mutable as String, to: textView)
        runSearch()
        return result(replaced: found.count)
    }

    func selectedText() async -> String {
        guard let textView else { return "" }
        return (textView.string as NSString).substring(with: textView.selectedRange())
    }

    func focusPane() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }
}

extension SourceEditorView.Coordinator: LineScrollable {
    func currentLine() async -> Double {
        topLine
    }
}
