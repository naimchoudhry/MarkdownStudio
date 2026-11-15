import AppKit
import SwiftUI

/// Revert for one tab (window): back to the text as it was when this tab opened the document, back to
/// the last save, or browse all versions. Each tab keeps its own "last opened" text.
@Observable
final class DocumentRevert {
    /// The document's text when this tab opened it.
    @ObservationIgnored private(set) var openedText: String?
    /// Replaces the document's text through the editor, so the change can be undone.
    @ObservationIgnored var replaceText: ((String) -> Void)?
    @ObservationIgnored var currentText: (() -> String)?
    @ObservationIgnored weak var window: NSWindow?

    func documentDidOpen(with text: String) {
        if openedText == nil { openedText = text }
    }

    private var document: NSDocument? {
        window.flatMap { NSDocumentController.shared.document(for: $0) }
    }

    /// Whether `text` differs from what this tab opened, so the Revert button should show.
    func hasChanges(in text: String) -> Bool {
        guard let openedText else { return false }
        return text != openedText
    }

    var canRevertToLastOpened: Bool {
        guard let openedText, let currentText else { return false }
        return currentText() != openedText
    }

    var canRevertToLastSaved: Bool { document?.fileURL != nil && document?.isDocumentEdited == true }
    var canBrowseVersions: Bool { document?.fileURL != nil }

    /// Asks first; the revert itself can be undone with Edit ▸ Undo.
    func revertToLastOpened() {
        guard let openedText, canRevertToLastOpened else { return }
        let alert = NSAlert()
        alert.messageText = "Revert to the version you opened?"
        alert.informativeText = "All changes made since this document was opened in this tab are removed. You can undo this with Edit ▸ Undo."
        alert.addButton(withTitle: "Revert")
        alert.addButton(withTitle: "Cancel")
        let apply = { [weak self] (response: NSApplication.ModalResponse) in
            guard response == .alertFirstButtonReturn else { return }
            self?.replaceText?(openedText)
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: apply)
        } else {
            apply(alert.runModal())
        }
    }

    /// The standard File ▸ Revert To Saved, which asks for confirmation itself.
    func revertToLastSaved() {
        document?.revertToSaved(nil)
    }

    /// The standard Time Machine-style version browser.
    func browseVersions() {
        document?.browseVersions(nil)
    }
}

/// Window toolbar menu for reverting the tab's document.
struct RevertMenu: View {
    let revert: DocumentRevert
    /// The document's text, so the menu's enabled states are worked out again whenever it changes.
    let text: String

    var body: some View {
        Menu {
            Button("Revert to Last Opened") { revert.revertToLastOpened() }
                .disabled(!revert.canRevertToLastOpened)
            Button("Revert to Last Saved") { revert.revertToLastSaved() }
                .disabled(!revert.canRevertToLastSaved)
            Divider()
            Button("Browse All Versions…") { revert.browseVersions() }
                .disabled(!revert.canBrowseVersions)
        } label: {
            Label("Revert", systemImage: "clock.arrow.circlepath")
        }
        .help("Revert this document to how it was when opened or last saved, or browse earlier versions")
    }
}
