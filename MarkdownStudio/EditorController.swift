import Observation
import SwiftUI
import WebKit

/// Formatting state at the selection in the rendered view, as reported by `editor.js`.
nonisolated struct EditorState: Decodable, Equatable {
    var focused = false
    var bold = false
    var italic = false
    var strikethrough = false
    var code = false
    var block = "p"
    var quote = false
    /// "", "bullet" or "ordered".
    var list = ""
    var marker = ""
    var task = false
    var link: String?
    /// Outline level shown in the rendered view: 0 = everything, 1–6 = titles up to that level,
    /// -1 = sections folded by hand.
    var outline = 0

    var textStyle: TextStyle { TextStyle(rawValue: block) ?? .body }
    var bulletStyle: BulletStyle? { list == "bullet" ? BulletStyle(rawValue: marker) ?? .disc : nil }
}

nonisolated enum TextStyle: String, CaseIterable, Identifiable {
    case body = "p"
    case title1 = "h1"
    case title2 = "h2"
    case title3 = "h3"
    case title4 = "h4"
    case title5 = "h5"
    case title6 = "h6"
    case codeBlock = "pre"

    var id: Self { self }

    var title: String {
        switch self {
        case .body: "Body"
        case .title1: "Title 1"
        case .title2: "Title 2"
        case .title3: "Title 3"
        case .title4: "Title 4"
        case .title5: "Title 5"
        case .title6: "Title 6"
        case .codeBlock: "Code Block"
        }
    }

    /// Used with ⌥⌘ in the Format menu.
    var shortcutKey: KeyEquivalent? {
        switch self {
        case .body: "0"
        case .title1: "1"
        case .title2: "2"
        case .title3: "3"
        case .title4: "4"
        case .title5: "5"
        case .title6: "6"
        case .codeBlock: nil
        }
    }
}

/// Bullet styles map to the Markdown bullet character, so the choice is saved in the file.
nonisolated enum BulletStyle: String, CaseIterable, Identifiable {
    case disc = "-"
    case circle = "*"
    case square = "+"

    var id: Self { self }

    var title: String {
        switch self {
        case .disc: "• Disc"
        case .circle: "◦ Circle"
        case .square: "▪ Square"
        }
    }
}

nonisolated enum EditorCommand {
    case bold
    case italic
    case strikethrough
    case inlineCode
    case textStyle(TextStyle)
    case bullets(BulletStyle)
    case numberedList
    case checklist
    case removeList
    case quote
    case link(String)
    case horizontalRule
    case clearFormatting
    /// 0 shows everything; 1–6 shows only titles up to that level.
    case outline(Int)
    case collapseAllSections

    /// The `editorCommand(name, value)` call in `editor.js`.
    var invocation: (name: String, value: String) {
        switch self {
        case .bold: ("bold", "")
        case .italic: ("italic", "")
        case .strikethrough: ("strikethrough", "")
        case .inlineCode: ("code", "")
        case .textStyle(let style): ("block", style.rawValue)
        case .bullets(let style): ("list", style.rawValue)
        case .numberedList: ("list", "ordered")
        case .checklist: ("list", "task")
        case .removeList: ("list", "none")
        case .quote: ("quote", "")
        case .link(let url): ("link", url)
        case .horizontalRule: ("rule", "")
        case .clearFormatting: ("clear", "")
        case .outline(let level): ("outline", String(level))
        case .collapseAllSections: ("outline", "collapse")
        }
    }

    /// Commands that only change what's shown, so they shouldn't take focus from the source pane.
    var isViewOnly: Bool {
        switch self {
        case .outline, .collapseAllSections: true
        default: false
        }
    }
}

/// Connects the formatting toolbar and Format menu to a document's rendered view.
@Observable
final class EditorController {
    var state = EditorState()
    /// Shows the link editor popover in the toolbar.
    var isEditingLink = false

    @ObservationIgnored weak var webView: WKWebView?

    func perform(_ command: EditorCommand) {
        guard let webView else { return }
        if !command.isViewOnly { webView.window?.makeFirstResponder(webView) }
        let (name, value) = command.invocation
        Task {
            _ = try? await webView.callAsyncJavaScript(
                "editorCommand(name, value)",
                arguments: ["name": name, "value": value],
                contentWorld: .page
            )
        }
    }

    func toggleBulletList() {
        perform(state.list == "bullet" ? .removeList : .bullets(.disc))
    }

    func toggleNumberedList() {
        perform(state.list == "ordered" ? .removeList : .numberedList)
    }
}
