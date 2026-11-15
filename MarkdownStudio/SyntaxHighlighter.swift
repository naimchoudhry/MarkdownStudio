import AppKit
import JavaScriptCore

/// Colours source code in the Markdown (source) pane, using the same tokenizer (`syntax.js`) and the
/// same Xcode-style colours as code blocks in the rendered pane. It runs in Apple's built-in
/// JavaScriptCore, and only sets the layout manager's temporary attributes, so the text is untouched.
@MainActor
final class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()

    /// Very large files are left uncoloured, to keep typing fast.
    static let maximumLength = 2_000_000

    private let context: JSContext?
    private let tokenizeFunction: JSValue?

    private init() {
        guard let url = Bundle.main.url(forResource: "syntax", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8),
              let context = JSContext() else {
            context = nil
            tokenizeFunction = nil
            return
        }
        context.evaluateScript(source)
        // Flattens the tokens into [start, end, typeIndex, …] in a typed array, which is cheap to read from Swift.
        context.evaluateScript("""
            function tokenizeFlat(code, language) {
              const definition = Syntax.language(language);
              if (!definition) return new Int32Array(0);
              const tokens = Syntax.tokenize(code, definition);
              const flat = new Int32Array(tokens.length * 3);
              tokens.forEach((token, index) => {
                flat[index * 3] = token.start;
                flat[index * 3 + 1] = token.end;
                flat[index * 3 + 2] = Syntax.TYPES.indexOf(token.type);
              });
              return flat;
            }
            """)
        self.context = context
        tokenizeFunction = context.objectForKeyedSubscript("tokenizeFlat")
        types = context.evaluateScript("Syntax.TYPES")?.toArray()?.compactMap { $0 as? String } ?? []
    }

    /// The token types, in `Syntax.TYPES` order.
    private var types: [String] = []

    /// The coloured ranges (UTF-16 offsets, as `NSString` uses) for `code`.
    func tokens(in code: String, language: String) -> [(range: NSRange, color: NSColor)] {
        guard let context, let tokenizeFunction,
              let result = tokenizeFunction.call(withArguments: [code, language]) else { return [] }
        let ref = context.jsGlobalContextRef
        guard let object = JSValueToObject(ref, result.jsValueRef, nil),
              let bytes = JSObjectGetTypedArrayBytesPtr(ref, object, nil) else { return [] }
        let count = JSObjectGetTypedArrayLength(ref, object, nil)
        let values = bytes.bindMemory(to: Int32.self, capacity: count)
        var tokens: [(range: NSRange, color: NSColor)] = []
        tokens.reserveCapacity(count / 3)
        for index in stride(from: 0, to: count - 2, by: 3) {
            let start = Int(values[index]), end = Int(values[index + 1]), type = Int(values[index + 2])
            guard type >= 0, type < types.count, let color = Self.colors[types[type]] else { continue }
            tokens.append((NSRange(location: start, length: end - start), color))
        }
        return tokens
    }

    /// Recolours all of the text view's text.
    func highlight(_ textView: NSTextView, language: String?) {
        guard let layoutManager = textView.layoutManager else { return }
        let string = textView.string
        let length = (string as NSString).length
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: length))
        guard let language, length > 0, length <= Self.maximumLength else { return }
        for token in tokens(in: string, language: language) where NSMaxRange(token.range) <= length {
            layoutManager.addTemporaryAttribute(.foregroundColor, value: token.color, forCharacterRange: token.range)
        }
    }

    // Xcode's default colours, matching editor.html.
    private static func color(light: UInt32, dark: UInt32) -> NSColor {
        func make(_ hex: UInt32) -> NSColor {
            NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        let (lightColor, darkColor) = (make(light), make(dark))
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }

    private static let colors: [String: NSColor] = {
        let keyword = color(light: 0x9B2393, dark: 0xFF7AB2)
        let property = color(light: 0x3900A0, dark: 0xA167E6)
        return [
            "keyword": keyword,
            "literal": keyword,
            "string": color(light: 0xC41A16, dark: 0xFF8170),
            "comment": color(light: 0x5D6C79, dark: 0x7F8C98),
            "number": color(light: 0x1C00CF, dark: 0xD9C97C),
            "type": color(light: 0x0B4F79, dark: 0x5DD8FF),
            "function": color(light: 0x326D74, dark: 0x67B7A4),
            "attribute": color(light: 0x815F03, dark: 0xCC9768),
            "preprocessor": color(light: 0x643820, dark: 0xFD8F3F),
            "property": property,
            "variable": property,
            "inserted": color(light: 0x1A7F37, dark: 0x3FB950),
            "deleted": color(light: 0xCF222E, dark: 0xF85149),
        ]
    }()
}
