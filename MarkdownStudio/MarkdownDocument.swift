import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    nonisolated static let markdownText = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// A text document: Markdown, or any other text file such as source code or a config file. The text is
/// read and written as UTF-8 exactly as it is, so a `.swift` or `.json` file stays what it was.
nonisolated struct MarkdownDocument: FileDocument {
    /// `.data` lets files without a recognised type, such as `.zshrc`, open too, as long as they're text.
    static let readableContentTypes: [UTType] = [
        .markdownText, .plainText, .text, .sourceCode, .script, .shellScript, .json, .xml, .yaml, .propertyList, .data,
    ]
    /// New documents are saved as Markdown or plain text; opened files are saved back as they were.
    static let writableContentTypes: [UTType] = [.markdownText, .plainText]

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // Only open text: refuse binary files rather than show (and risk saving) garbage.
        guard !data.prefix(8192).contains(0), let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
