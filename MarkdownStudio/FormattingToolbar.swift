import SwiftUI

/// Formatting controls shown above the rendered view.
struct FormattingToolbar: View {
    @Bindable var controller: EditorController
    @State private var linkURL = ""

    private var state: EditorState { controller.state }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                editingControls
                    .padding(.leading, 10)
            }

            // View controls, kept at the right edge.
            HStack(spacing: 4) {
                separator
                outlineMenu
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(.trailing, 10)
        }
        .frame(height: 36)
        .background(.bar)
    }

    private var editingControls: some View {
        HStack(spacing: 4) {
            Picker("Text Style", selection: textStyle) {
                ForEach(TextStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .labelsHidden()
            .fixedSize()
            .help("Text style")

            separator

            toggle("Bold", systemImage: "bold", shortcut: "⌘B", isOn: state.bold) { controller.perform(.bold) }
            toggle("Italic", systemImage: "italic", shortcut: "⌘I", isOn: state.italic) { controller.perform(.italic) }
            toggle("Strikethrough", systemImage: "strikethrough", shortcut: "⇧⌘X", isOn: state.strikethrough) {
                controller.perform(.strikethrough)
            }
            toggle("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right", shortcut: "⌥⌘C", isOn: state.code) {
                controller.perform(.inlineCode)
            }
            Button("Clear Formatting", systemImage: "eraser") { controller.perform(.clearFormatting) }
                .help("Clear Formatting")

            separator

            bulletMenu
            toggle("Numbered List", systemImage: "list.number", shortcut: "⇧⌘9", isOn: state.list == "ordered") {
                controller.toggleNumberedList()
            }
            toggle("Checklist", systemImage: "checklist", shortcut: "⇧⌘L", isOn: state.task) {
                controller.perform(.checklist)
            }

            separator

            toggle("Block Quote", systemImage: "text.quote", shortcut: "⌘'", isOn: state.quote) { controller.perform(.quote) }
            toggle("Code Block", systemImage: "curlybraces.square", shortcut: nil, isOn: state.textStyle == .codeBlock) {
                controller.perform(.textStyle(.codeBlock))
            }
            toggle("Link", systemImage: "link", shortcut: "⌘K", isOn: state.link != nil) {
                controller.isEditingLink = true
            }
            .popover(isPresented: $controller.isEditingLink, arrowEdge: .bottom) { linkEditor }
            Button("Horizontal Rule", systemImage: "minus") { controller.perform(.horizontalRule) }
                .help("Horizontal Rule")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private var textStyle: Binding<TextStyle> {
        Binding(get: { state.textStyle }, set: { controller.perform(.textStyle($0)) })
    }

    private var separator: some View {
        Divider().frame(height: 18).padding(.horizontal, 4)
    }

    private func toggle(
        _ title: String,
        systemImage: String,
        shortcut: String?,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: { _ in action() })) {
            Label(title, systemImage: systemImage)
        }
        .toggleStyle(.button)
        .help(shortcut.map { "\(title) (\($0))" } ?? title)
    }

    private var bulletMenu: some View {
        Menu {
            Picker("Bullet Style", selection: bulletStyle) {
                ForEach(BulletStyle.allCases) { style in
                    Text(style.title).tag(Optional(style))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Remove List") { controller.perform(.removeList) }
                .disabled(state.list.isEmpty)
        } label: {
            Label("Bulleted List", systemImage: "list.bullet")
        } primaryAction: {
            controller.toggleBulletList()
        }
        .menuStyle(.button)
        .fixedSize()
        .tint(state.list == "bullet" ? .accentColor : nil)
        .help("Bulleted List (⇧⌘7) — click the arrow for bullet styles")
    }

    /// Chooses which title levels the rendered view shows; sections can also be folded by hand.
    private var outlineMenu: some View {
        Menu {
            outlineToggle("Show Everything", level: 0)
            Divider()
            outlineToggle("Title 1 Only", level: 1)
            ForEach(2...6, id: \.self) { level in
                outlineToggle("Titles 1–\(level)", level: level)
            }
            Divider()
            Button("Collapse All Sections") { controller.perform(.collapseAllSections) }
            Button("Expand All Sections") { controller.perform(.outline(0)) }
        } label: {
            Label("Outline", systemImage: "list.bullet.indent")
        }
        .menuIndicator(.visible)
        .fixedSize()
        .tint(state.outline != 0 ? .accentColor : nil)
        .help("Show only titles up to a chosen level, or collapse and expand all sections")
    }

    private func outlineToggle(_ title: String, level: Int) -> some View {
        Toggle(title, isOn: Binding(get: { state.outline == level }, set: { _ in controller.perform(.outline(level)) }))
    }

    private var bulletStyle: Binding<BulletStyle?> {
        Binding(get: { state.bulletStyle }, set: { style in
            if let style { controller.perform(.bullets(style)) }
        })
    }

    private var linkEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.link == nil ? "Add Link" : "Edit Link").font(.headline)
            TextField("https://example.com", text: $linkURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit(applyLink)
            HStack {
                if state.link != nil {
                    Button("Remove Link") {
                        controller.isEditingLink = false
                        controller.perform(.link(""))
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { controller.isEditingLink = false }
                    .keyboardShortcut(.cancelAction)
                Button("Apply", action: applyLink)
                    .keyboardShortcut(.defaultAction)
                    .disabled(linkURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .onAppear { linkURL = state.link ?? "" }
    }

    private func applyLink() {
        let url = linkURL.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        controller.isEditingLink = false
        controller.perform(.link(url))
    }
}
