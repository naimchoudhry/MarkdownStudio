import SwiftUI

/// Help ▸ Version History: what changed in each release, newest first.
struct VersionHistoryView: View {
    static let windowID = "version-history"

    @AppStorage(ViewZoom.key) private var zoom = 1.0

    var body: some View {
        RenderedEditorView(markdown: .constant(VersionHistory.markdown), isEditable: false, zoom: zoom)
            .frame(minWidth: 480, minHeight: 400)
    }
}

enum VersionHistory {
    /// The version of this copy of the app, as shown in About Markdown Studio.
    static var currentVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    static var markdown: String {
        "# Version History\n\nYou're using Markdown Studio **\(currentVersion)**.\n\n" + releases
    }

    private static let releases = #"""
    ## 1.3 — November 2026

    **Text and code files**

    - Open any text file for quick editing, not just Markdown: plain text, source code and config files such as `.txt`, `.swift`, `.py`, `.json` and `.zshrc`.
    - These files get a single source pane, without the rendered pane, headed with the file's format: **Swift**, **JSON**, **Python** and so on, with a line count.
    - Code is coloured in Xcode's colours, as you type. Swift, Python, JavaScript, TypeScript, JSON, shell scripts, HTML, XML, CSS, C, C++, Objective-C, Java, Kotlin, C#, Go, Rust, Ruby, SQL, YAML and diffs are recognised from the file's extension or name.
    - Files are saved back exactly as they were, with the same name and type.
    - Open any text file from Terminal with `open -a MarkdownStudio <file>`.

    **Also new**

    - Images next to a document, with relative paths such as `docs/images/photo.png`, are shown in the rendered pane. Allow access to their folder once, from the bar above the rendered pane, and Markdown Studio remembers it.
    - **Revert** button in the window toolbar (shown once the document has changed), and File ▸ Revert to Last Opened (⌥⌘Z): go back to the document as it was when opened in that tab, to the last save, or browse all earlier versions. Each tab keeps its own.
    - Markdown documents open with the rendered pane taking two thirds of the window and the Markdown pane one third.
    - Help ▸ Version History (this window).
    - The Show/Hide Markdown Pane button is easier to spot, in the app's accent colour.
    - The **+** button in the tab bar asks whether to create a new document or open existing ones, in new tabs.
    - The Show File Path button has a new path icon, so it no longer looks like an Open button.

    **Fixes**

    - The View ▸ Show Tab Bar setting is remembered again.
    - Showing the Markdown pane again no longer jumps both panes back to the top of the document when scrolling is linked.
    - Typing and Undo (⌘Z) in the rendered pane no longer make it jump, for example near the end of a document.

    ## 1.2 — November 2026

    - **Hide the Markdown pane** to see only the formatted document. Use the button at the left of the Markdown pane's header, **View ▸ Show or Hide Markdown Pane**, or ⌃⌘M. While it's hidden, the button sits at the start of the formatting toolbar.
    - Each tab keeps its own layout, so you can hide the Markdown pane in one tab and keep both panes in another.
    - The pane comes back at its previous width, scrolled to the same place as the rendered pane.
    - The Markdown pane has a soft, paper-textured light gray background.

    ## 1.1 — October 2026

    - **Syntax colouring** for fenced code blocks in the rendered pane, in Xcode's light and dark colours. Name the language after the opening fence, for example ```` ```swift ````.

    ## 1.0 — October 2026

    The first release.

    - **Two editable panes:** Markdown source on the left and the formatted document on the right, each updating the other as you type.
    - **Formatting toolbar** with text styles (Body, Title 1–6, Code Block), bold, italic, strikethrough, inline code, bullet styles, numbered lists, checklists, block quotes, links and horizontal rules.
    - **Copy and paste** that understands Markdown.
    - **Find & Replace** in either pane, with match case, whole words, wrap around and regular expressions.
    - **Linked scrolling** to keep both panes aligned, line for line.
    - **Collapsible sections** and an **outline view** showing only Titles 1–N.
    - **Zoom**, **Dark Mode** (On, Off or System Default) and **file paths** in the window title and tabs.
    - **Tabs or windows** for opened documents.
    - **Markdown Studio Guide** in the Help menu, with a complete Markdown syntax reference.
    """#
}
