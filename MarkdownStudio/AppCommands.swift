import SwiftUI

/// The Format menu. Its items act on the rendered view and are enabled while it has focus,
/// so shortcuts like ⌘B don't fire while typing in the source.
struct FormatCommands: Commands {
    @ObservedObject private var active = ActiveDocument.shared
    private var controller: EditorController? { ActiveDocument.shared.current()?.editor }
    private var isRenderedEditorFocused: Bool { active.isRenderedEditorFocused }

    var body: some Commands {
        CommandMenu("Format") {
            Group {
                Button("Bold") { controller?.perform(.bold) }
                    .keyboardShortcut("b")
                Button("Italic") { controller?.perform(.italic) }
                    .keyboardShortcut("i")
                Button("Strikethrough") { controller?.perform(.strikethrough) }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Button("Inline Code") { controller?.perform(.inlineCode) }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                Button("Link…") { controller?.isEditingLink = true }
                    .keyboardShortcut("k")

                Divider()

                Menu("Text Style") {
                    ForEach(TextStyle.allCases) { style in
                        Button(style.title) { controller?.perform(.textStyle(style)) }
                            .keyboardShortcut(style.shortcutKey.map { KeyboardShortcut($0, modifiers: [.command, .option]) })
                    }
                }

                Menu("Lists") {
                    Button("Bulleted List") { controller?.toggleBulletList() }
                        .keyboardShortcut("7", modifiers: [.command, .shift])
                    ForEach(BulletStyle.allCases) { style in
                        Button("Bullet Style: \(style.title)") { controller?.perform(.bullets(style)) }
                    }
                    Divider()
                    Button("Numbered List") { controller?.toggleNumberedList() }
                        .keyboardShortcut("9", modifiers: [.command, .shift])
                    Button("Checklist") { controller?.perform(.checklist) }
                        .keyboardShortcut("l", modifiers: [.command, .shift])
                    Divider()
                    Button("Remove List") { controller?.perform(.removeList) }
                }

                Button("Block Quote") { controller?.perform(.quote) }
                    .keyboardShortcut("'")
                Button("Horizontal Rule") { controller?.perform(.horizontalRule) }

                Divider()

                Button("Clear Formatting") { controller?.perform(.clearFormatting) }
            }
            .disabled(!isRenderedEditorFocused)
        }
    }
}

/// Replaces the default Help menu with links into the in-app guide.
struct HelpCommands: Commands {
    let navigation: GuideNavigation
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Markdown Studio Guide") { show(GuideContent.welcomeID) }
                .keyboardShortcut("?")
            Button("Markdown Syntax Reference") { show(GuideContent.syntaxID) }
            Button("Keyboard Shortcuts") { show(GuideContent.shortcutsID) }
        }
    }

    private func show(_ sectionID: GuideSection.ID) {
        navigation.selection = sectionID
        openWindow(id: GuideView.windowID)
    }
}

/// Edit ▸ Find, replacing the standard text-finding items with the window's find bar.
struct FindCommands: Commands {
    @ObservedObject private var active = ActiveDocument.shared
    /// Resolved when a command runs, so it always acts on the window in front.
    private var find: FindController? { ActiveDocument.shared.current()?.find }

    var body: some Commands {
        CommandGroup(replacing: .textEditing) {
            // Always enabled: each command does nothing (or beeps) when it doesn't apply. Enabling them
            // from find-bar state would go stale, as menus don't observe it.
            Menu("Find") {
                Button("Find…") { find?.toggle() }
                    .keyboardShortcut("f")
                Button("Find and Replace…") { find?.toggleReplace() }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Button("Find Next") { find?.findNext() }
                    .keyboardShortcut("g")
                Button("Find Previous") { find?.findPrevious() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { find?.useSelectionForFind() }
                    .keyboardShortcut("e")
                Divider()
                Button("Replace") { find?.replaceCurrent() }
                Button("Replace All") { find?.replaceAll() }
                Divider()
                Button("Hide Find Bar") { find?.close() }
            }
        }
    }
}

/// View menu items for zoom, appearance, linked scrolling and outline.
struct ScrollCommands: Commands {
    @ObservedObject private var active = ActiveDocument.shared
    @AppStorage(AppAppearance.key) private var appearance = AppAppearance.system
    @AppStorage(PathTitle.showPathKey) private var showsFilePath = true
    private var scrollSync: ScrollSync? { ActiveDocument.shared.current()?.scroll }
    private var editor: EditorController? { ActiveDocument.shared.current()?.editor }

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            Button("Zoom In") { ViewZoom.zoomIn() }
                .keyboardShortcut("+")
            Button("Zoom Out") { ViewZoom.zoomOut() }
                .keyboardShortcut("-")
            Button("Actual Size") { ViewZoom.reset() }
                .keyboardShortcut("0")
            Divider()
            Toggle("Show File Path in Title", isOn: $showsFilePath)
            Picker("Dark Mode", selection: AppAppearance.binding($appearance)) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            Divider()
            Button("Toggle Linked Scrolling") { scrollSync?.toggle() }
                .keyboardShortcut("l", modifiers: [.command, .option])
            Button("Align Rendered to Markdown") { scrollSync?.align(to: .markdown) }
            Button("Align Markdown to Rendered") { scrollSync?.align(to: .rendered) }
            Divider()
            Menu("Outline") {
                Button("Show Everything") { editor?.perform(.outline(0)) }
                    .keyboardShortcut("0", modifiers: [.command, .control])
                Divider()
                ForEach(1...6, id: \.self) { level in
                    Button(level == 1 ? "Title 1 Only" : "Titles 1–\(level)") { editor?.perform(.outline(level)) }
                        .keyboardShortcut(KeyEquivalent(Character(String(level))), modifiers: [.command, .control])
                }
                Divider()
                Button("Collapse All Sections") { editor?.perform(.collapseAllSections) }
                Button("Expand All Sections") { editor?.perform(.outline(0)) }
            }
            Divider()
        }
    }
}

/// File menu: where newly opened documents go.
struct OpenCommands: Commands {
    @AppStorage(OpenPlacement.key) private var placement = OpenPlacement.ask

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open in New Tab…") { WindowPlacement.shared.openDocuments(in: .tab) }
                .keyboardShortcut("o", modifiers: [.command, .option])
            Button("Open in New Window…") { WindowPlacement.shared.openDocuments(in: .window) }
            Picker("Open Documents In", selection: $placement) {
                ForEach(OpenPlacement.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        }
    }
}
