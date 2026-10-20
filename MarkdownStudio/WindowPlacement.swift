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

    /// File ▸ Open in New Tab / Open in New Window.
    func openDocuments(in placement: OpenPlacement) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdownText, .plainText]
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
