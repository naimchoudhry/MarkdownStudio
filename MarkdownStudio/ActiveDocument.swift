import AppKit
import Combine
import SwiftUI

/// The controllers belonging to one document window.
struct DocumentControllers {
    let editor: EditorController
    let find: FindController
    let scroll: ScrollSync
}

/// Tracks the document window in front, so menu commands act on it.
/// An `ObservableObject` because menu commands refresh reliably for these (not for `@Observable`).
final class ActiveDocument: ObservableObject {
    static let shared = ActiveDocument()

    @Published private(set) var controllers: DocumentControllers?
    /// Bumped when the front document's rendered-view focus changes, so the Format menu updates.
    @Published private(set) var isRenderedEditorFocused = false

    private var byWindow: [ObjectIdentifier: DocumentControllers] = [:]
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: nil) { [weak self] note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated { self?.windowDidBecomeKey(window) }
        })
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: nil) { [weak self] note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated { self?.windowWillClose(window) }
        })
    }

    /// The document whose window is in front, looked up now rather than from the last notification.
    func current() -> DocumentControllers? {
        for window in [NSApp.keyWindow, NSApp.mainWindow] {
            if let window, let controllers = byWindow[ObjectIdentifier(window)] { return controllers }
        }
        return nil
    }


    /// The frontmost other visible document window, which a new document can join as a tab.
    func frontDocumentWindow(excluding window: NSWindow) -> NSWindow? {
        NSApp.orderedWindows.first { candidate in
            candidate !== window && candidate.isVisible && byWindow[ObjectIdentifier(candidate)] != nil
        }
    }

    func register(_ controllers: DocumentControllers, for window: NSWindow) {
        byWindow[ObjectIdentifier(window)] = controllers
        if window.isKeyWindow || NSApp.keyWindow === window { windowDidBecomeKey(window) }
    }

    private func windowDidBecomeKey(_ window: NSWindow?) {
        // Only publish real changes: every assignment to a @Published property triggers a menu update.
        let front = window.flatMap { byWindow[ObjectIdentifier($0)] }
        if front?.editor !== controllers?.editor { controllers = front }
        let focused = front?.editor.state.focused == true
        if focused != isRenderedEditorFocused { isRenderedEditorFocused = focused }
    }

    /// Called by a document when its rendered view gains or loses focus.
    func renderedEditorFocusChanged(_ focused: Bool, in editor: EditorController) {
        // Focus means this document is in front, even if its window became key before it registered.
        if focused, controllers?.editor !== editor, let front = current(), front.editor === editor {
            controllers = front
        }
        guard controllers?.editor === editor, isRenderedEditorFocused != focused else { return }
        isRenderedEditorFocused = focused
    }

    private func windowWillClose(_ window: NSWindow?) {
        guard let window else { return }
        byWindow[ObjectIdentifier(window)] = nil
        if window.isKeyWindow { controllers = nil }
    }
}

/// Reports the window a view is in, once it's added to one.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {}

    final class ReaderView: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow?(window) }
        }
    }
}
