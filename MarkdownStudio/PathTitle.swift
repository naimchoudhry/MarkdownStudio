import AppKit
import SwiftUI

/// Shows as much of the document's folder path as fits in the window title and its tab,
/// truncating whole folder names from the front: `…/parent/folder/file.md`.
struct PathTitle: NSViewRepresentable {
    static let showPathKey = "ShowFilePathInTitle"

    let fileURL: URL?
    /// When off, the title and tab show just the file name.
    var showsPath = true

    func makeNSView(context: Context) -> TitleView {
        let view = TitleView()
        view.fileURL = fileURL
        view.showsPath = showsPath
        return view
    }

    func updateNSView(_ view: TitleView, context: Context) {
        guard view.fileURL != fileURL || view.showsPath != showsPath else { return }
        view.fileURL = fileURL
        view.showsPath = showsPath
        view.updateTitles()
    }

    static func dismantleNSView(_ view: TitleView, coordinator: ()) {
        view.stopObserving()
    }

    final class TitleView: NSView {
        var fileURL: URL?
        var showsPath = true
        private var observers: [NSObjectProtocol] = []
        private var titleObservation: NSKeyValueObservation?
        private var desiredTitle: String?
        /// What the titles were last fitted to, so the frequent update notification is cheap.
        private var fittedFor: FitInputs?

        /// The measured space for each label, taken after the title bar has laid out.
        private struct FitInputs: Equatable {
            var titleWidth: CGFloat
            var tabWidth: CGFloat
            var url: URL?
            var showsPath: Bool
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            // Posted after the window processes events, including resizing and tabs being added or
            // removed; the titles are only refitted when the width, tab count or file changed.
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: window, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateTitlesIfNeeded() }
            })
            // Resizing (including in code, which posts no update) is refitted once the title bar has laid out.
            for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: nil) { [weak self] _ in
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self?.updateTitlesIfNeeded() }
                    }
                })
            }
            // The document system resets the title (e.g. after saving); put ours back.
            titleObservation = window.observe(\.title) { [weak self] _, _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.reapplyTitleIfReset() }
                }
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.updateTitles() }
            }
        }

        func stopObserving() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            titleObservation = nil
        }

        private func reapplyTitleIfReset() {
            guard let window, let desiredTitle, window.title != desiredTitle else { return }
            window.title = desiredTitle
        }

        private func fitInputs(for window: NSWindow) -> FitInputs {
            // Tabs share the tab bar equally.
            let tabCount = CGFloat(max(window.tabbedWindows?.count ?? 1, 1))
            let tabBarWidth = tabBar(in: window)?.bounds.width ?? window.frame.width
            return FitInputs(
                titleWidth: availableTitleWidth(in: window),
                tabWidth: tabBarWidth / tabCount - 64, // close button and padding
                url: fileURL,
                showsPath: showsPath
            )
        }

        private func updateTitlesIfNeeded() {
            guard let window, fitInputs(for: window) != fittedFor else { return }
            updateTitles()
        }

        func updateTitles() {
            guard let window, let fileURL else { return }
            let inputs = fitInputs(for: window)
            fittedFor = inputs
            guard showsPath else {
                let name = fileURL.lastPathComponent
                desiredTitle = name
                if window.title != name { window.title = name }
                if window.tab.title != name { window.tab.title = name }
                return
            }
            let titleFont = titleField(in: window)?.font ?? .titleBarFont(ofSize: 0)
            let title = PathTitle.fitting(fileURL, width: inputs.titleWidth, font: titleFont)
            desiredTitle = title
            if window.title != title { window.title = title }

            let tabWidth = inputs.tabWidth
            let tabTitle = PathTitle.fitting(fileURL, width: tabWidth, font: .systemFont(ofSize: NSFont.systemFontSize))
            if window.tab.title != tabTitle { window.tab.title = tabTitle }
        }

        /// Width of the toolbar's title area, less the document icon and autosave button beside the title.
        private func availableTitleWidth(in window: NSWindow) -> CGFloat {
            guard let titleView = descendant(of: window.contentView?.superview, named: "NSToolbarTitleView") else {
                return window.frame.width * 0.4
            }
            return max(titleView.bounds.width - 70, 80)
        }

        private func titleField(in window: NSWindow) -> NSTextField? {
            descendant(of: window.contentView?.superview, named: "_NSToolbarTitleField") as? NSTextField
        }

        private func tabBar(in window: NSWindow) -> NSView? {
            descendant(of: window.contentView?.superview, named: "NSTabBarTrackView")
        }

        private func descendant(of view: NSView?, named className: String) -> NSView? {
            guard let view else { return nil }
            if String(describing: type(of: view)) == className { return view }
            for subview in view.subviews {
                if let match = descendant(of: subview, named: className) { return match }
            }
            return nil
        }
    }

    /// The longest form of the path that fits: `~/a/b/file.md`, then `…/b/file.md`, then `…/file.md`.
    static func fitting(_ url: URL, width: CGFloat, font: NSFont) -> String {
        // The sandbox's home is the app container, so abbreviate the user's real home folder.
        var path = url.path
        if let home = getpwuid(getuid())?.pointee.pw_dir.map({ String(cString: $0) }), path.hasPrefix(home + "/") {
            path = "~" + path.dropFirst(home.count)
        }
        var components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if path.hasPrefix("/") { components.insert("", at: 0) } // keep the leading "/" for absolute paths
        let fileName = components.last ?? url.lastPathComponent
        func fits(_ text: String) -> Bool {
            (text as NSString).size(withAttributes: [.font: font]).width <= width
        }

        let full = components.joined(separator: "/")
        if fits(full) { return full }
        var best = fileName
        for count in 1..<components.count {
            let candidate = "…/" + components.suffix(count).joined(separator: "/")
            guard fits(candidate) else { break }
            best = candidate
        }
        return best
    }
}
