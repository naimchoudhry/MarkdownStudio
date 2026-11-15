import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Where a newly opened document goes when a document window is already open.
enum OpenPlacement: String, CaseIterable, Identifiable {
    case ask
    case tab
    case window
    case system

    static let key = "OpenDocumentsIn"

    var id: Self { self }

    var title: String {
        switch self {
        case .ask: "Ask Each Time"
        case .tab: "New Tab"
        case .window: "New Window"
        case .system: "System Setting"
        }
    }

    static var current: OpenPlacement {
        OpenPlacement(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .ask
    }
}

/// Puts each new document window in a tab or its own window, according to the user's choice.
final class WindowPlacement {
    static let shared = WindowPlacement()

    /// A fixed tabbing identifier for document windows. SwiftUI's default is built from the document's
    /// file types, so it (and with it the remembered View ▸ Show Tab Bar setting) changes whenever the
    /// supported types do.
    static let tabbingIdentifier = "MarkdownStudio.Document"

    /// Carries the View ▸ Show Tab Bar setting over from SwiftUI's old, type-based tabbing identifiers (once).
    /// AppKit stores "shown" as true and "hidden" by removing the key, so only a shown tab bar is copied.
    static func migrateTabBarSetting() {
        let defaults = UserDefaults.standard
        let migratedKey = "TabBarSettingMigrated"
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)
        let prefix = "NSWindowTabbingShoudShowTabBarKey-"
        let wasShown = defaults.dictionaryRepresentation().contains { key, value in
            key.hasPrefix(prefix + "SwiftUI-DocumentGroup") && (value as? Bool) == true
        }
        if wasShown { defaults.set(true, forKey: prefix + tabbingIdentifier) }
    }

    /// Windows restored at launch keep their saved arrangement.
    var hasFinishedLaunching = false
    /// One-off choices from Open in New Tab / New Window, used by the next windows that open.
    private var pendingOverrides: [OpenPlacement] = []
    /// Weak, so a closed window's reused address isn't mistaken for a window already placed.
    private let handledWindows = NSHashTable<NSWindow>.weakObjects()

    /// Called when a document window's content is installed, usually before the window is shown.
    func place(_ window: NSWindow) {
        guard !handledWindows.contains(window) else { return }
        handledWindows.add(window)
        let placement = pendingOverrides.isEmpty ? OpenPlacement.current : pendingOverrides.removeFirst()
        guard hasFinishedLaunching, placement != .system,
              let host = ActiveDocument.shared.frontDocumentWindow(excluding: window) else { return }

        // Steer AppKit's own tabbing before the window is shown; it's checked and corrected below.
        switch placement {
        case .tab: window.tabbingMode = .preferred
        case .window: window.tabbingMode = .disallowed
        case .ask, .system: break
        }
        Task {
            // Wait until the window is on screen (up to a few seconds); tabs can only be arranged then.
            for _ in 0..<60 where !window.isVisible {
                try? await Task.sleep(for: .milliseconds(50))
            }
            try? await Task.sleep(for: .milliseconds(100))
            guard window.isVisible else { return }
            if placement == .ask {
                ask(about: window, host: host)
            } else {
                arrange(window, host: host, placement)
            }
        }
    }

    private func arrange(_ window: NSWindow, host: NSWindow, _ placement: OpenPlacement) {
        defer { window.tabbingMode = .automatic }
        let isTabbedWithHost = host.tabbedWindows?.contains(window) == true
        if placement == .tab, !isTabbedWithHost {
            host.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        } else if placement == .window, (window.tabbedWindows?.count ?? 1) > 1 {
            window.moveTabToNewWindow(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func ask(about window: NSWindow, host: NSWindow) {
        let alert = NSAlert()
        alert.messageText = "Open “\(window.representedURL?.lastPathComponent ?? "this document")” in a new tab or a new window?"
        alert.informativeText = "You can change this later in File ▸ Open Documents In."
        alert.addButton(withTitle: "New Tab")
        alert.addButton(withTitle: "New Window")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Always do this"
        alert.beginSheetModal(for: window) { response in
            MainActor.assumeIsolated {
                let choice: OpenPlacement = response == .alertFirstButtonReturn ? .tab : .window
                if alert.suppressionButton?.state == .on {
                    UserDefaults.standard.set(choice.rawValue, forKey: OpenPlacement.key)
                }
                self.arrange(window, host: host, choice)
            }
        }
    }

    /// A new untitled document, placed like `openDocuments(in:)`.
    func newDocument(in placement: OpenPlacement) {
        pendingOverrides.append(placement)
        NSDocumentController.shared.newDocument(nil)
    }

    /// Responders for the tab bar's + button, kept alive here: a window doesn't retain its next responder.
    private let newTabResponders = NSMapTable<NSWindow, NewTabResponder>.weakToStrongObjects()

    /// Makes the tab bar's + button ask whether to create a new document or open existing ones.
    func handleNewTabButton(in window: NSWindow) {
        guard newTabResponders.object(forKey: window) == nil else { return }
        let responder = NewTabResponder(window: window)
        // The window passes the button's action on to its next responder (SwiftUI's window controller,
        // which would create an untitled document); this responder goes in between and handles it first.
        responder.nextResponder = window.nextResponder
        window.nextResponder = responder
        newTabResponders.setObject(responder, forKey: window)
    }

    /// File ▸ Open in New Tab / Open in New Window.
    func openDocuments(in placement: OpenPlacement) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = MarkdownDocument.readableContentTypes
        panel.allowsMultipleSelection = true
        panel.begin { response in
            MainActor.assumeIsolated {
                guard response == .OK else { return }
                for url in panel.urls {
                    self.pendingOverrides.append(placement)
                    NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, alreadyOpen, error in
                        // No new window opens for these, so don't leave the choice waiting for another one.
                        guard alreadyOpen || error != nil else { return }
                        MainActor.assumeIsolated {
                            if let index = self.pendingOverrides.firstIndex(of: placement) {
                                self.pendingOverrides.remove(at: index)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Handles the tab bar's + button by asking whether to create a new document or open existing ones,
/// in new tabs of this window.
final class NewTabResponder: NSResponder {
    private weak var window: NSWindow?

    init(window: NSWindow) {
        self.window = window
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func newWindowForTab(_ sender: Any?) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "New Tab"
        alert.informativeText = "Create a new document, or open existing documents in new tabs?"
        alert.addButton(withTitle: "New Document")
        alert.addButton(withTitle: "Open…")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in
            MainActor.assumeIsolated {
                switch response {
                case .alertFirstButtonReturn: WindowPlacement.shared.newDocument(in: .tab)
                case .alertSecondButtonReturn: WindowPlacement.shared.openDocuments(in: .tab)
                default: break
                }
            }
        }
    }
}
