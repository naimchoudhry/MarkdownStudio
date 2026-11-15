import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// Folders the user has allowed Markdown Studio to read images from. The app is sandboxed, so it can
/// only read the document it opened; images next to it need the user's permission, given once per
/// folder in an Open panel and remembered with security-scoped bookmarks.
@MainActor
final class FolderAccess {
    static let shared = FolderAccess()

    private static let bookmarksKey = "ImageFolderBookmarks"
    /// Folders readable in this session, by path.
    private var readable: Set<String> = []

    /// Whether `file` is inside an allowed folder (starting access to that folder if needed).
    func canRead(_ file: URL) -> Bool {
        let path = file.standardizedFileURL.path
        if readable.contains(where: { Self.path(path, isInside: $0) }) { return true }
        var bookmarks = UserDefaults.standard.dictionary(forKey: Self.bookmarksKey) as? [String: Data] ?? [:]
        for (folder, data) in bookmarks where Self.path(path, isInside: folder) {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
                                     bookmarkDataIsStale: &isStale),
                  url.startAccessingSecurityScopedResource() else {
                bookmarks[folder] = nil
                UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)
                continue
            }
            readable.insert(folder)
            if isStale { remember(url) }
            return true
        }
        return false
    }

    /// Asks the user to allow a folder, starting at `folder`. Returns whether they did.
    func requestAccess(startingAt folder: URL, in window: NSWindow?) async -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        panel.prompt = "Allow"
        panel.message = "Allow Markdown Studio to show images from this folder and the folders inside it. "
            + "If the document's images are elsewhere, choose a folder that contains them."
        let response: NSApplication.ModalResponse
        if let window {
            response = await panel.beginSheetModal(for: window)
        } else {
            response = panel.runModal()
        }
        guard response == .OK, let url = panel.url else { return false }
        readable.insert(url.standardizedFileURL.path)
        remember(url)
        return true
    }

    private func remember(_ url: URL) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else { return }
        var bookmarks = UserDefaults.standard.dictionary(forKey: Self.bookmarksKey) as? [String: Data] ?? [:]
        bookmarks[url.standardizedFileURL.path] = data
        UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)
    }

    private static func path(_ path: String, isInside folder: String) -> Bool {
        folder == "/" || path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/")
    }
}

/// Serves files next to the document to the rendered pane, which can't read them itself. Relative image
/// paths resolve against `localfile://file/<document folder>/` (set as the page's base URL).
@MainActor
final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "localfile"

    /// Called when a file can't be shown because its folder hasn't been allowed yet.
    var onBlocked: (() -> Void)?

    static func baseURL(for document: URL?) -> String {
        guard let folder = document?.deletingLastPathComponent() else { return "" }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "file"
        components.path = folder.standardizedFileURL.path.hasSuffix("/") ? folder.standardizedFileURL.path : folder.standardizedFileURL.path + "/"
        return components.url?.absoluteString ?? ""
    }

    /// The file a `localfile:` URL refers to.
    static func fileURL(for url: URL) -> URL? {
        guard url.scheme == scheme else { return nil }
        return URL(fileURLWithPath: url.path(percentEncoded: false))
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, let file = Self.fileURL(for: url) else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        guard FolderAccess.shared.canRead(file) else {
            onBlocked?()
            task.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        guard let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mimeType = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        task.didReceive(URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

/// Shown above the rendered pane when the document has images Markdown Studio isn't allowed to read yet.
struct ImageAccessBar: View {
    let controller: EditorController
    let documentURL: URL?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.badge.exclamationmark")
                .foregroundStyle(.secondary)
            Text("Allow access to show this document's images.")
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Button("Not Now") { controller.isImageAccessNeeded = false }
                .buttonStyle(.borderless)
            Button("Allow Access…") {
                Task {
                    let folder = documentURL?.deletingLastPathComponent() ?? FileManager.default.homeDirectoryForCurrentUser
                    if await FolderAccess.shared.requestAccess(startingAt: folder, in: controller.webView?.window) {
                        controller.isImageAccessNeeded = false
                        controller.reloadImages()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.bar)
    }
}
