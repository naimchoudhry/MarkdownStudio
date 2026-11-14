import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    var fileURL: URL?
    @State private var controller = EditorController()
    @State private var find = FindController()
    @State private var scrollSync = ScrollSync()
    @State private var layout = PaneLayout()
    @AppStorage(ViewZoom.key) private var zoom = 1.0
    @AppStorage(PathTitle.showPathKey) private var showsFilePath = true

    var body: some View {
        VStack(spacing: 0) {
            if find.isVisible {
                FindBar(find: find)
                Divider()
            }

            HSplitView {
                if layout.isMarkdownPaneVisible {
                    VStack(spacing: 0) {
                        SourceHeader(text: document.text, layout: layout)
                        Divider()
                        SourceEditorView(text: $document.text, findController: find, scrollSync: scrollSync, zoom: zoom)
                    }
                    .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(spacing: 0) {
                    FormattingToolbar(controller: controller, layout: layout)
                    Divider()
                    RenderedEditorView(
                        markdown: $document.text, controller: controller, findController: find, scrollSync: scrollSync, zoom: zoom
                    )
                }
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $showsFilePath) {
                    Label("Show File Path", systemImage: "folder")
                }
                .toggleStyle(.button)
                .help(showsFilePath ? "Hide the file's folder path in the title and tabs" : "Show the file's folder path in the title and tabs")
                DarkModeMenu()
                ZoomButtons(zoom: zoom)
                ScrollLinkButton(scrollSync: scrollSync)
                Button("Find", systemImage: "magnifyingglass") { find.toggle() }
                    .help("Show or hide Find (⌘F)")
            }
        }
        .onChange(of: layout.isMarkdownPaneVisible) { _, visible in
            if visible {
                // The pane is recreated at its minimum width and scrolled to the top: restore its width,
                // then bring it to where the rendered pane is.
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    layout.restoreDividerPosition()
                    try? await Task.sleep(for: .milliseconds(100))
                    scrollSync.align(to: .rendered)
                }
            } else {
                // Searches can only run in the pane that's still showing.
                find.target = .rendered
                find.renderedEngine?.focusPane()
            }
        }
        .onChange(of: controller.state.focused) { _, focused in
            ActiveDocument.shared.renderedEditorFocusChanged(focused, in: controller)
        }
        .background(PathTitle(fileURL: fileURL, showsPath: showsFilePath))
        .background(WindowReader { window in
            // Keep the content (and the split view's divider) below the title bar, toolbar and tab bar.
            window.styleMask.remove(.fullSizeContentView)
            layout.window = window
            ActiveDocument.shared.register(
                DocumentControllers(editor: controller, find: find, scroll: scrollSync, layout: layout), for: window
            )
            WindowPlacement.shared.place(window)
        })
    }
}

/// Zooms the text in both panes; the tooltips show the current zoom.
private struct ZoomButtons: View {
    let zoom: Double

    var body: some View {
        ControlGroup {
            Button("Zoom Out", systemImage: "textformat.size.smaller") { ViewZoom.zoomOut() }
                .disabled(zoom <= ViewZoom.levels.first! + 0.001)
                .help("Zoom Out (⌘−) — currently \(ViewZoom.percentage(zoom))")
            Button("Zoom In", systemImage: "textformat.size.larger") { ViewZoom.zoomIn() }
                .disabled(zoom >= ViewZoom.levels.last! - 0.001)
                .help("Zoom In (⌘+) — currently \(ViewZoom.percentage(zoom))")
        } label: {
            Label("Zoom", systemImage: "textformat.size")
        }
    }
}

/// Toggles linked scrolling, plus a menu choosing which pane the other aligns to when linking is turned on.
private struct ScrollLinkButton: View {
    @Bindable var scrollSync: ScrollSync

    var body: some View {
        ControlGroup {
            Toggle(isOn: $scrollSync.isLinked) {
                Label("Link Scrolling", systemImage: "arrow.up.and.down.text.horizontal")
            }
            .toggleStyle(.button)
            .help(scrollSync.isLinked
                  ? "Scrolling is linked (⌥⌘L). Click to scroll the panes independently."
                  : "Scrolling is independent (⌥⌘L). Click to link and align to the \(scrollSync.anchor.title) pane.")

            Menu {
                Picker("When Linking, Align To", selection: $scrollSync.anchor) {
                    ForEach(ScrollSync.Pane.allCases) { pane in
                        Text("\(pane.title) Pane").tag(pane)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Button("Align Rendered to Markdown Now") { scrollSync.align(to: .markdown) }
                Button("Align Markdown to Rendered Now") { scrollSync.align(to: .rendered) }
            } label: {
                Label("Scrolling Options", systemImage: "chevron.down")
            }
            .menuIndicator(.hidden)
            .help("Choose which pane to align to")
        } label: {
            Label("Link Scrolling", systemImage: "arrow.up.and.down.text.horizontal")
        }
    }
}

/// Hides or shows the Markdown pane. It sits at the end of the Markdown pane's header, and moves to the start
/// of the formatting toolbar while the pane is hidden.
struct MarkdownPaneButton: View {
    let layout: PaneLayout

    var body: some View {
        let visible = layout.isMarkdownPaneVisible
        Button(visible ? "Hide Markdown Pane" : "Show Markdown Pane", systemImage: "sidebar.left") {
            layout.toggleMarkdownPane()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help(visible ? "Hide the Markdown pane (⌃⌘M)" : "Show the Markdown pane (⌃⌘M)")
    }
}

/// Title bar for the source pane, matching the height of the formatting toolbar.
private struct SourceHeader: View {
    let text: String
    let layout: PaneLayout

    var body: some View {
        HStack {
            Label("Markdown", systemImage: "number")
                .font(.callout.weight(.medium))
            Spacer()
            Text("\(wordCount) words")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            MarkdownPaneButton(layout: layout)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(height: 36)
        .background(.bar)
    }

    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}

#Preview {
    ContentView(document: .constant(MarkdownDocument(text: "# Hello\n\nSome **bold** text.")), fileURL: nil)
}
