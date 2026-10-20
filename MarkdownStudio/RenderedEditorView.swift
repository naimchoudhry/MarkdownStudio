import AppKit
import SwiftUI
import WebKit

/// Editable, rendered (WYSIWYG) view of the Markdown, hosted in a `WKWebView`.
/// The page converts Markdown → HTML for display and HTML → Markdown after edits.
struct RenderedEditorView: NSViewRepresentable {
    @Binding var markdown: String
    var controller: EditorController?
    var findController: FindController?
    var scrollSync: ScrollSync?
    var isEditable = true
    var zoom = 1.0

    func makeCoordinator() -> Coordinator {
        Coordinator(markdown: $markdown, isEditable: isEditable)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        for name in Coordinator.messageNames {
            configuration.userContentController.add(context.coordinator, name: name)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.pageZoom = zoom
        context.coordinator.webView = webView
        context.coordinator.controller = controller
        context.coordinator.findController = findController
        context.coordinator.scrollSync = scrollSync
        controller?.webView = webView
        findController?.renderedEngine = context.coordinator
        scrollSync?.renderedPane = context.coordinator

        if let url = Bundle.main.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        context.coordinator.render(markdown)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.pageZoom != zoom { webView.pageZoom = zoom }
        context.coordinator.markdown = $markdown
        context.coordinator.render(markdown)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        for name in Coordinator.messageNames {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let messageNames = ["markdown", "state", "openLink", "find", "scroll"]

        var markdown: Binding<String>
        weak var webView: WKWebView?
        weak var controller: EditorController?
        weak var findController: FindController?
        weak var scrollSync: ScrollSync?
        private let isEditable: Bool
        /// The Markdown the page is currently showing, used to avoid echoing edits back.
        private var displayedMarkdown: String?
        fileprivate var pendingScrollLine: Double?
        fileprivate var isApplyingScroll = false
        private var isLoaded = false

        init(markdown: Binding<String>, isEditable: Bool) {
            self.markdown = markdown
            self.isEditable = isEditable
        }

        func render(_ text: String) {
            guard text != displayedMarkdown else { return }
            displayedMarkdown = text
            guard isLoaded else { return }
            push(text)
        }

        private func push(_ text: String) {
            Task {
                _ = await call("setMarkdown(markdown)", ["markdown": text])
                scrollSync?.renderedPaneDidReload()
            }
        }

        fileprivate func call(_ body: String, _ arguments: [String: Any] = [:]) async -> Any? {
            guard let webView else { return nil }
            return try? await webView.callAsyncJavaScript(body, arguments: arguments, contentWorld: .page)
        }

        fileprivate func callForResult(_ body: String, _ arguments: [String: Any] = [:]) async -> FindResult {
            guard let json = await call(body, arguments) as? String,
                  let result = try? JSONDecoder().decode(FindResult.self, from: Data(json.utf8)) else { return FindResult() }
            return result
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scroll", let line = message.body as? Double {
                scrollSync?.pane(.rendered, didScrollTo: line)
                return
            }
            guard let body = message.body as? String else { return }
            switch message.name {
            case "markdown":
                guard isEditable, body != displayedMarkdown else { return }
                displayedMarkdown = body
                markdown.wrappedValue = body
            case "state":
                guard let state = try? JSONDecoder().decode(EditorState.self, from: Data(body.utf8)),
                      state != controller?.state else { return }
                if state.focused && controller?.state.focused != true {
                    findController?.paneDidBecomeActive(.rendered)
                }
                controller?.state = state
            case "find":
                guard let result = try? JSONDecoder().decode(FindResult.self, from: Data(body.utf8)) else { return }
                findController?.engine(self, didUpdate: result)
            case "openLink":
                guard let url = URL(string: body), ["http", "https", "mailto"].contains(url.scheme?.lowercased()) else { return }
                NSWorkspace.shared.open(url)
            default:
                break
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let text = displayedMarkdown ?? markdown.wrappedValue
            let isEditable = isEditable
            Task {
                _ = await call("setEditable(editable); setMarkdown(markdown)", ["editable": isEditable, "markdown": text])
                if isEditable { scrollSync?.renderedPaneDidReload() }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .cancel }
            if navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return url.isFileURL ? .allow : .cancel
        }
    }
}

extension RenderedEditorView.Coordinator: FindEngine {
    func find(_ search: FindSearch?) async -> FindResult {
        guard let search else { return await callForResult("return findSearch(null)") }
        let arguments: [String: Any] = [
            "query": search.query, "isRegex": search.isRegex, "matchCase": search.matchCase, "mode": search.mode.rawValue,
        ]
        return await callForResult("return findSearch(search)", ["search": arguments])
    }

    func selectMatch(at index: Int) async {
        _ = await call("return findSelect(index)", ["index": index])
    }

    func replaceMatch(at index: Int, with replacement: String) async -> FindResult {
        await callForResult("return findReplace(index, replacement)", ["index": index, "replacement": replacement])
    }

    func replaceAll(with replacement: String) async -> FindResult {
        await callForResult("return findReplaceAll(replacement)", ["replacement": replacement])
    }

    func selectedText() async -> String {
        await call("return selectedText()") as? String ?? ""
    }

    func focusPane() {
        guard let webView else { return }
        webView.window?.makeFirstResponder(webView)
    }
}

extension RenderedEditorView.Coordinator: LineScrollable {
    func currentLine() async -> Double {
        await call("return currentLine()") as? Double ?? 0
    }

    /// Coalesces requests: while one scroll is being applied, only the latest target is kept, so a
    /// fast trackpad scroll in the source pane never builds up a backlog of stale positions.
    func scroll(toLine line: Double) {
        pendingScrollLine = line
        guard !isApplyingScroll else { return }
        isApplyingScroll = true
        Task {
            while let next = pendingScrollLine {
                pendingScrollLine = nil
                _ = await call("scrollToLine(line)", ["line": next])
            }
            isApplyingScroll = false
        }
    }
}
