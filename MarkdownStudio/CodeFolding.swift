import AppKit

/// Folding for JSON files: an object or array that spans several lines can be collapsed to `{…}` or
/// `[…]`, with the arrows in a narrow margin beside the text, or all at once. Only how the text is
/// shown changes; the text itself, and so the file, is untouched.
///
/// Folded text is hidden by the layout manager: its glyphs are generated as null glyphs, and its line
/// breaks take no space, so the closing bracket follows the `…` on the opening line.
final class CodeFolding: NSObject, NSLayoutManagerDelegate {
    private(set) weak var textView: NSTextView?
    private weak var scrollView: NSScrollView?
    private var ruler: FoldingRuler?

    /// A bracketed block spanning more than one line.
    struct Block {
        let open: Int
        let close: Int
        let depth: Int
    }

    /// Folded blocks: opening bracket offset → closing bracket offset (UTF-16, as `NSString` uses).
    private var folded: [Int: Int] = [:]
    /// The outermost folded blocks, in order, which are the ones that decide what's hidden.
    private var visibleFolds: [(open: Int, close: Int)] = []
    private var cachedBlocks: [Block]?

    var isAttached: Bool { textView != nil }

    func attach(to textView: NSTextView, in scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        textView.layoutManager?.delegate = self
        let ruler = FoldingRuler(scrollView: scrollView, folding: self)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        self.ruler = ruler
    }

    func detach() {
        unfoldAll()
        textView?.layoutManager?.delegate = nil
        scrollView?.rulersVisible = false
        scrollView?.hasVerticalRuler = false
        scrollView?.verticalRulerView = nil
        ruler = nil
        textView = nil
        scrollView = nil
    }

    // MARK: Blocks

    /// Every bracketed block spanning more than one line, in order of their opening brackets.
    var blocks: [Block] {
        if let cachedBlocks { return cachedBlocks }
        var result: [Block] = []
        var stack: [(offset: Int, line: Int)] = []
        var line = 0
        var inString = false
        var escaped = false
        for (offset, unit) in (textView?.string ?? "").utf16.enumerated() {
            if inString {
                if escaped { escaped = false }
                else if unit == 0x5C { escaped = true } // backslash
                else if unit == 0x22 { inString = false }
                else if unit == 0x0A { line += 1 }
                continue
            }
            switch unit {
            case 0x22: inString = true
            case 0x0A: line += 1
            case 0x7B, 0x5B: stack.append((offset, line)) // { [
            case 0x7D, 0x5D: // } ]
                if let open = stack.popLast(), open.line < line {
                    result.append(Block(open: open.offset, close: offset, depth: stack.count))
                }
            default: break
            }
        }
        result.sort { $0.open < $1.open }
        cachedBlocks = result
        return result
    }

    /// The blocks with an arrow in the margin: the first to open on each line.
    func markers(in characterRange: NSRange) -> [(block: Block, isFolded: Bool)] {
        guard let string = textView?.string as NSString? else { return [] }
        var lastLineStart = -1
        var result: [(Block, Bool)] = []
        for block in blocks where NSLocationInRange(block.open, characterRange) {
            guard !isHidden(block.open) else { continue }
            let lineStart = string.lineRange(for: NSRange(location: block.open, length: 0)).location
            guard lineStart != lastLineStart else { continue }
            lastLineStart = lineStart
            result.append((block, folded[block.open] != nil))
        }
        return result
    }

    // MARK: Folding

    func toggle(_ block: Block) {
        if folded[block.open] != nil {
            folded[block.open] = nil
        } else {
            folded[block.open] = block.close
            moveSelectionOutOfFolds(block)
        }
        foldsDidChange(NSRange(location: block.open, length: block.close - block.open + 1))
    }

    /// Folds every block inside the outermost one, so the top level stays open.
    func foldAll() {
        for block in blocks where block.depth > 0 { folded[block.open] = block.close }
        if let first = visibleFoldsAfterUpdate().first { moveSelectionOutOfFolds(Block(open: first.open, close: first.close, depth: 0)) }
        foldsDidChange(nil)
    }

    func unfoldAll() {
        guard !folded.isEmpty else { return }
        folded.removeAll()
        foldsDidChange(nil)
    }

    /// Unfolds whatever hides any of `range`, such as a find match.
    func reveal(_ range: NSRange) {
        let hiding = folded.filter { open, close in
            NSIntersectionRange(NSRange(location: open + 1, length: close - open - 1), range).length > 0
                || NSLocationInRange(range.location, NSRange(location: open + 1, length: close - open - 1))
        }
        guard !hiding.isEmpty else { return }
        for open in hiding.keys { folded[open] = nil }
        foldsDidChange(nil)
    }

    /// The block whose `…` is at `characterIndex`, if any, so clicking it unfolds the block.
    func foldedBlock(atEllipsis characterIndex: Int) -> Block? {
        guard let fold = visibleFolds.first(where: { $0.open + 1 == characterIndex }) else { return nil }
        return Block(open: fold.open, close: fold.close, depth: 0)
    }

    private func moveSelectionOutOfFolds(_ block: Block) {
        guard let textView else { return }
        let selection = textView.selectedRange()
        if selection.location > block.open, selection.location <= block.close {
            textView.setSelectedRange(NSRange(location: block.close + 1, length: 0))
        }
    }

    private func visibleFoldsAfterUpdate() -> [(open: Int, close: Int)] {
        var result: [(open: Int, close: Int)] = []
        for (open, close) in folded.sorted(by: { $0.key < $1.key }) {
            if let last = result.last, open < last.close { continue } // inside an outer fold
            result.append((open, close))
        }
        return result
    }

    private func foldsDidChange(_ range: NSRange?) {
        visibleFolds = visibleFoldsAfterUpdate()
        guard let textView, let layoutManager = textView.layoutManager else { return }
        let length = (textView.string as NSString).length
        let invalid = range.map { NSIntersectionRange($0, NSRange(location: 0, length: length)) }
            ?? NSRange(location: 0, length: length)
        layoutManager.invalidateGlyphs(forCharacterRange: invalid, changeInLength: 0, actualCharacterRange: nil)
        layoutManager.invalidateLayout(forCharacterRange: invalid, actualCharacterRange: nil)
        textView.needsDisplay = true
        ruler?.needsDisplay = true
    }

    // MARK: Editing

    /// Keeps the folds in place as text is inserted or removed around them, and unfolds any block
    /// that the edit touches.
    func textWillChange(in range: NSRange, replacementLength: Int) {
        guard !folded.isEmpty else { return }
        let delta = replacementLength - range.length
        var updated: [Int: Int] = [:]
        var touched = false
        for (open, close) in folded {
            if NSMaxRange(range) <= open {
                updated[open + delta] = close + delta
            } else if range.location > close {
                updated[open] = close
            } else {
                touched = true
            }
        }
        folded = updated
        visibleFolds = visibleFoldsAfterUpdate()
        if touched { needsFullRefresh = true }
    }

    private var needsFullRefresh = false

    func textDidChange() {
        cachedBlocks = nil
        // Drop folds whose brackets no longer pair up after the edit.
        let valid = Dictionary(blocks.map { ($0.open, $0.close) }, uniquingKeysWith: { first, _ in first })
        let stale = folded.filter { valid[$0.key] != $0.value }
        if !stale.isEmpty || needsFullRefresh {
            for open in stale.keys { folded[open] = nil }
            needsFullRefresh = false
            foldsDidChange(nil)
        } else {
            ruler?.needsDisplay = true
        }
    }

    // MARK: Hiding

    /// Whether the character is hidden by a fold (the `…` itself is not).
    func isHidden(_ index: Int) -> Bool {
        guard let fold = fold(containing: index) else { return false }
        return index != fold.open + 1
    }

    /// The outermost fold whose hidden part (between its brackets) contains `index`.
    private func fold(containing index: Int) -> (open: Int, close: Int)? {
        var low = 0, high = visibleFolds.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let fold = visibleFolds[mid]
            if index <= fold.open { high = mid - 1 }
            else if index >= fold.close { low = mid + 1 }
            else { return fold }
        }
        return nil
    }

    func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes charIndexes: UnsafePointer<Int>, font aFont: NSFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        guard !visibleFolds.isEmpty else { return 0 }
        var newGlyphs: [CGGlyph]?
        var newProperties: [NSLayoutManager.GlyphProperty]?
        for index in 0..<glyphRange.length {
            let character = charIndexes[index]
            guard let fold = fold(containing: character) else { continue }
            if newGlyphs == nil {
                newGlyphs = Array(UnsafeBufferPointer(start: glyphs, count: glyphRange.length))
                newProperties = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
            }
            if character == fold.open + 1 {
                newGlyphs![index] = Self.ellipsisGlyph(in: aFont)
                newProperties![index] = []
            } else {
                newProperties![index] = .null
            }
        }
        guard let newGlyphs, let newProperties else { return 0 }
        layoutManager.setGlyphs(newGlyphs, properties: newProperties, characterIndexes: charIndexes,
                                font: aFont, forGlyphRange: glyphRange)
        return glyphRange.length
    }

    func layoutManager(_ layoutManager: NSLayoutManager, shouldUse action: NSLayoutManager.ControlCharacterAction,
                       forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        fold(containing: charIndex) != nil ? .zeroAdvancement : action
    }

    private static func ellipsisGlyph(in font: NSFont) -> CGGlyph {
        var character: UniChar = 0x2026
        var glyph: CGGlyph = 0
        CTFontGetGlyphsForCharacters(font as CTFont, &character, &glyph, 1)
        return glyph
    }
}

/// The margin beside a JSON file's text, with an arrow by each block that can be folded.
final class FoldingRuler: NSRulerView {
    private weak var folding: CodeFolding?
    static let width: CGFloat = 16

    init(scrollView: NSScrollView, folding: CodeFolding) {
        self.folding = folding
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = scrollView.documentView
        ruleThickness = Self.width
        reservedThicknessForMarkers = 0
        reservedThicknessForAccessoryView = 0
        // Redraw the arrows as the text scrolls or is laid out again (zooming, resizing).
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.documentView?.postsFrameChangedNotifications = true
        let center = NotificationCenter.default
        for (name, object) in [(NSView.boundsDidChangeNotification, scrollView.contentView as NSView?),
                               (NSView.frameDidChangeNotification, scrollView.documentView)] {
            observers.append(center.addObserver(forName: name, object: object, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.needsDisplay = true }
            })
        }
    }

    private var observers: [NSObjectProtocol] = []

    isolated deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var requiredThickness: CGFloat { Self.width }

    private var textView: NSTextView? { clientView as? NSTextView }

    /// Each arrow's block and the rect of its line, in this view's coordinates.
    private func markerRects() -> [(block: CodeFolding.Block, isFolded: Bool, rect: NSRect)] {
        guard let folding, let textView, let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return [] }
        let visible = textView.visibleRect
        let glyphs = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        return folding.markers(in: characters).map { block, isFolded in
            let glyph = layoutManager.glyphIndexForCharacter(at: block.open)
            var line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            line.origin.y += textView.textContainerOrigin.y
            let top = convert(NSPoint(x: 0, y: line.minY), from: textView).y
            return (block, isFolded, NSRect(x: 0, y: top, width: bounds.width, height: line.height))
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        (textView?.backgroundColor ?? .textBackgroundColor).setFill()
        dirtyRect.intersection(bounds).fill()
        let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            .applying(.init(hierarchicalColor: .secondaryLabelColor))
        for marker in markerRects() where marker.rect.intersects(dirtyRect) {
            let name = marker.isFolded ? "chevron.right" : "chevron.down"
            guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration) else { continue }
            let size = image.size
            image.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: marker.rect.midY - size.height / 2,
                                  width: size.width, height: size.height))
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let marker = markerRects().first(where: { $0.rect.minY <= point.y && point.y < $0.rect.maxY }) else { return }
        folding?.toggle(marker.block)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }
}
