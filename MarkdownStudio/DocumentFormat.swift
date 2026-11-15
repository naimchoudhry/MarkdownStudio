import Foundation

/// What kind of file a document is, worked out from its name. Markdown files get the two-pane editor;
/// everything else (plain text, source code, config files) gets a single plain-text pane, with syntax
/// colouring when the language is known. The file's contents and type are never changed.
struct DocumentFormat: Equatable {
    /// The name shown in the pane header, such as "Swift" or "Plain Text".
    let name: String
    /// The `syntax.js` language used for colouring, or nil for none.
    let syntaxLanguage: String?
    let isMarkdown: Bool

    static let markdown = DocumentFormat(name: "Markdown", syntaxLanguage: nil, isMarkdown: true)
    static let plainText = DocumentFormat(name: "Plain Text", syntaxLanguage: nil, isMarkdown: false)

    /// Untitled documents are Markdown until they're saved under another name.
    init(url: URL?) {
        guard let url else { self = .markdown; return }
        let filename = url.lastPathComponent.lowercased()
        if let format = Self.byFilename[filename] {
            self = format
        } else if let format = Self.byExtension[url.pathExtension.lowercased()] {
            self = format
        } else {
            self = .plainText
        }
    }

    private init(name: String, syntaxLanguage: String?, isMarkdown: Bool = false) {
        self.name = name
        self.syntaxLanguage = syntaxLanguage
        self.isMarkdown = isMarkdown
    }

    private static func code(_ name: String, _ language: String?) -> DocumentFormat {
        DocumentFormat(name: name, syntaxLanguage: language)
    }

    private static let byExtension: [String: DocumentFormat] = {
        var table: [String: DocumentFormat] = [:]
        func add(_ extensions: String, _ format: DocumentFormat) {
            for ext in extensions.split(separator: " ") { table[String(ext)] = format }
        }
        add("md markdown mdown mkd", .markdown)
        add("txt text", .plainText)
        add("log", code("Log", nil))
        add("csv", code("CSV", nil))
        add("tsv", code("TSV", nil))
        add("swift", code("Swift", "swift"))
        add("py pyw", code("Python", "python"))
        add("js mjs cjs jsx", code("JavaScript", "javascript"))
        add("ts tsx mts cts", code("TypeScript", "typescript"))
        add("json jsonc json5 geojson", code("JSON", "json"))
        add("sh bash zsh command", code("Shell Script", "shell"))
        add("fish", code("Fish Script", "shell"))
        add("html htm xhtml", code("HTML", "html"))
        add("xml xsd xsl svg", code("XML", "xml"))
        add("plist entitlements", code("Property List", "plist"))
        add("css", code("CSS", "css"))
        add("scss", code("SCSS", "scss"))
        add("less", code("Less", "less"))
        add("c", code("C", "c"))
        add("h", code("C Header", "c"))
        add("cpp cc cxx c++", code("C++", "cpp"))
        add("hpp hh hxx", code("C++ Header", "cpp"))
        add("m", code("Objective-C", "objc"))
        add("mm", code("Objective-C++", "objc"))
        add("java", code("Java", "java"))
        add("kt kts", code("Kotlin", "kotlin"))
        add("cs", code("C#", "csharp"))
        add("go", code("Go", "go"))
        add("rs", code("Rust", "rust"))
        add("rb rake gemspec", code("Ruby", "ruby"))
        add("sql", code("SQL", "sql"))
        add("yaml yml", code("YAML", "yaml"))
        add("diff patch", code("Diff", "diff"))
        add("toml", code("TOML", nil))
        add("ini cfg conf", code("Config", nil))
        add("env", code("Environment", "shell"))
        return table
    }()

    /// Files known by their whole name, such as shell start-up files.
    private static let byFilename: [String: DocumentFormat] = {
        let shell = code("Shell Script", "shell")
        var table: [String: DocumentFormat] = [:]
        for name in [".zshrc", ".zprofile", ".zshenv", ".zlogin", ".zlogout", ".bashrc", ".bash_profile",
                     ".bash_login", ".bash_logout", ".profile", ".aliases", ".env"] {
            table[name] = shell
        }
        table["makefile"] = code("Makefile", "shell")
        table["dockerfile"] = code("Dockerfile", "shell")
        table["gemfile"] = code("Ruby", "ruby")
        table["podfile"] = code("Ruby", "ruby")
        table["package.swift"] = code("Swift", "swift")
        for name in [".gitignore", ".gitattributes", ".gitconfig", ".editorconfig", ".npmrc"] {
            table[name] = code("Config", nil)
        }
        return table
    }()
}
