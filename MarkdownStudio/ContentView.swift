import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    var fileURL: URL?
    @State private var controller = EditorController()
    @State private var find = FindController()
    @State private var scrollSync = ScrollSync()
    @AppStorage(ViewZoom.key) private var zoom = 1.0
    @AppStorage(PathTitle.showPathKey) private var showsFilePath = true

    var body: some View {
        VStack(spacing: 0) {
            if find.isVisible {
                FindBar(find: find)
                Divider()
            }

            HSplitView {
                VStack(spacing: 0) {
                    SourceHeader(text: document.text)
                    Divider()
                    SourceEditorView(text: $document.text, findController: find, scrollSync: scrollSync, zoom: zoom)
                }
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    FormattingToolbar(controller: controller)
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
        .onChange(of: controller.state.focused) { _, focused in
            ActiveDocument.shared.renderedEditorFocusChanged(focused, in: controller)
        }
        .background(PathTitle(fileURL: fileURL, showsPath: showsFilePath))
        .background(WindowReader { window in
            // Keep the content (and the split view's divider) below the title bar, toolbar and tab bar.
            window.styleMask.remove(.fullSizeContentView)
            ActiveDocument.shared.register(
                DocumentControllers(editor: controller, find: find, scroll: scrollSync), for: window
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

/// Title bar for the source pane, matching the height of the formatting toolbar.
private struct SourceHeader: View {
    let text: String

    var body: some View {
        HStack {
            Label("Markdown", systemImage: "number")
                .font(.callout.weight(.medium))
            Spacer()
            Text("\(wordCount) words")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
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
