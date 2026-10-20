import SwiftUI

/// Find & replace bar shown across the top of a document window.
struct FindBar: View {
    @Bindable var find: FindController
    @FocusState private var focusedField: Field?

    private enum Field {
        case find
        case replace
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            GridRow {
                Picker("Mode", selection: $find.showsReplace) {
                    Text("Find").tag(false)
                    Text("Replace").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .help("Show or hide the replace field (⌥⌘F)")

                findField

                HStack(spacing: 8) {
                    ControlGroup {
                        Button("Previous", systemImage: "chevron.left", action: find.findPrevious)
                            .help("Find Previous (⇧⌘G)")
                        Button("Next", systemImage: "chevron.right", action: find.findNext)
                            .help("Find Next (⌘G)")
                    }
                    .fixedSize()
                    .disabled(find.matchCount == 0)

                    Picker("Search In", selection: $find.target) {
                        ForEach(FindController.Target.allCases) { target in
                            Text(target.title).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .help("Search the Markdown source or the rendered text")

                    Spacer(minLength: 0)

                    Button("Done") { find.close() }
                        .keyboardShortcut(.cancelAction)
                }
            }

            if find.showsReplace {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

                    TextField("Replace", text: $find.replacement)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .replace)
                        .onSubmit(find.replaceCurrent)
                        .help(find.useRegex ? "Use $1, $2… to insert captured groups, and $0 for the whole match" : "")

                    HStack(spacing: 8) {
                        Button("Replace", action: find.replaceCurrent)
                            .disabled(find.currentIndex == nil)
                        Button("Replace All", action: find.replaceAll)
                            .disabled(find.matchCount == 0)
                        if let status = find.statusMessage {
                            Text(status)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .controlSize(.regular)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.bar)
        .onChange(of: find.focusRequest, initial: true) { focusedField = .find }
    }

    private var findField: some View {
        HStack(spacing: 6) {
            optionsMenu

            TextField("Find", text: $find.query)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .find)
                .onSubmit(find.findNext)
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.shift) else { return .ignored }
                    find.findPrevious()
                    return .handled
                }

            Text(matchDescription)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(find.errorMessage == nil ? Color.secondary : Color.red)
                .lineLimit(1)
                .fixedSize()

            if !find.query.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { find.query = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
        .frame(minWidth: 220, idealWidth: 360, maxWidth: 520)
    }

    private var optionsMenu: some View {
        Menu {
            Toggle("Match Case", isOn: $find.matchCase)
            Toggle("Regular Expression", isOn: $find.useRegex)
            Toggle("Wrap Around", isOn: $find.wrapsAround)
            Divider()
            Picker("Match", selection: $find.mode) {
                ForEach(FindMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: find.useRegex ? "magnifyingglass.circle.fill" : "magnifyingglass")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
        .help("Search options")
    }

    private var matchDescription: String {
        if let error = find.errorMessage { return error }
        guard !find.query.isEmpty else { return "" }
        switch (find.matchCount, find.currentIndex) {
        case (0, _): return "No matches"
        case (let count, let index?): return "\(index + 1) of \(count)"
        case (1, nil): return "1 match"
        case (let count, nil): return "\(count) matches"
        }
    }
}
