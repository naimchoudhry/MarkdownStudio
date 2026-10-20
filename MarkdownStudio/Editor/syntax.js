'use strict';

// A small syntax highlighter for fenced code blocks. It only produces token ranges; editor.js
// colours them with the CSS Custom Highlight API, so the editable text is never modified.
const Syntax = (() => {
  const words = s => new Set(s.split(/\s+/).filter(Boolean));
  const re = source => new RegExp(source.source, 'y' + source.flags.replace(/[gy]/g, ''));

  // Shared rules
  const LINE_COMMENT = ['comment', /\/\/[^\n]*/];
  const BLOCK_COMMENT = ['comment', /\/\*[\s\S]*?(?:\*\/|$)/];
  const HASH_COMMENT = ['comment', /#[^\n]*/];
  const DOUBLE_QUOTED = ['string', /"(?:[^"\\\n]|\\.)*"?/];
  const SINGLE_QUOTED = ['string', /'(?:[^'\\\n]|\\.)*'?/];
  const NUMBER = ['number', /\b(?:0[xX][\da-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)[a-zA-Z]*\b/];
  const IDENT = ['ident', /[A-Za-z_$][\w$]*/];

  const C_TYPES = 'void char short int long float double signed unsigned bool size_t';

  const LANGUAGES = {
    swift: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['string', /#?"""[\s\S]*?(?:"""#?|$)/], DOUBLE_QUOTED,
        ['attribute', /@\w+/], ['preprocessor', /#\w+/], NUMBER, IDENT],
      keywords: words(`actor any as associatedtype async await break case catch class continue convenience default defer
        deinit didSet do dynamic else enum extension fallthrough fileprivate final for func get guard if import in indirect
        init inout internal is lazy let mutating nonisolated nonmutating open operator optional override private
        precedencegroup protocol public repeat required rethrows return set some static struct subscript super switch
        throw throws try typealias unowned var weak where while willSet consuming borrowing sending`),
      literals: words('true false nil self Self'),
      declaresFunction: words('func'),
      declaresType: words('class struct enum protocol extension actor typealias associatedtype'),
      capitalizedTypes: true,
    },
    python: {
      rules: [HASH_COMMENT,
        ['string', /[rRbBuUfF]{0,2}(?:'''[\s\S]*?(?:'''|$)|"""[\s\S]*?(?:"""|$))/],
        ['string', /[rRbBuUfF]{0,2}(?:'(?:[^'\\\n]|\\.)*'?|"(?:[^"\\\n]|\\.)*"?)/],
        ['attribute', /@[\w.]+/], NUMBER, IDENT],
      keywords: words(`and as assert async await break class continue def del elif else except finally for from global if
        import in is lambda nonlocal not or pass raise return try while with yield match case`),
      literals: words('True False None self cls'),
      types: words('int float str bool list dict set tuple bytes object type complex frozenset'),
      declaresFunction: words('def'),
      declaresType: words('class'),
      capitalizedTypes: true,
    },
    javascript: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['string', /`(?:[^`\\]|\\[\s\S])*`?/], DOUBLE_QUOTED, SINGLE_QUOTED, NUMBER, IDENT],
      keywords: words(`async await break case catch class const continue debugger default delete do else export extends
        finally for from function get if import in instanceof let new of return set static super switch this throw try
        typeof var void while with yield as`),
      literals: words('true false null undefined NaN Infinity'),
      declaresFunction: words('function'),
      declaresType: words('class'),
      capitalizedTypes: true,
    },
    json: {
      rules: [['property', /"(?:[^"\\\n]|\\.)*"(?=\s*:)/], DOUBLE_QUOTED, ['number', /-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/], IDENT],
      keywords: words(''),
      literals: words('true false null'),
    },
    shell: {
      rules: [['comment', /(?<=^|\s)#[^\n]*/], DOUBLE_QUOTED, SINGLE_QUOTED,
        ['variable', /\$(?:\{[^}\n]*\}|\w+|[@*#?$!0-9-])/], ['ident', /[A-Za-z_][\w.-]*/]],
      keywords: words(`if then else elif fi for while until do done case esac in function return local export readonly
        declare unset shift break continue exit source alias select time`),
      literals: words('true false'),
      commandWords: true,
    },
    html: {
      rules: [['comment', /<!--[\s\S]*?(?:-->|$)/], ['keyword', /<!DOCTYPE[^>]*>/i], ['keyword', /<\/?[A-Za-z][\w:-]*/],
        ['keyword', /\/?>/], ['attribute', /[A-Za-z_:][\w:.-]*(?==)/], DOUBLE_QUOTED, SINGLE_QUOTED,
        ['literal', /&[#\w]+;/]],
    },
    css: {
      rules: [BLOCK_COMMENT, LINE_COMMENT, DOUBLE_QUOTED, SINGLE_QUOTED, ['keyword', /@[\w-]+/], ['keyword', /!important/],
        ['number', /#[\da-fA-F]{3,8}\b/], ['number', /-?(?:\d+\.?\d*|\.\d+)(?:px|em|rem|%|vh|vw|vmin|vmax|ch|ex|pt|s|ms|deg|fr)?/],
        ['property', /[\w-]+(?=\s*:(?![\w-]*\s*[{,]))/], ['type', /[.#][\w-]+/], ['ident', /[\w-]+/]],
      keywords: words(''),
      literals: words('inherit initial unset none auto transparent currentColor'),
    },
    c: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['preprocessor', /#\s*\w+/], DOUBLE_QUOTED, SINGLE_QUOTED, NUMBER, IDENT],
      keywords: words(`auto break case const continue default do else enum extern for goto if inline register restrict
        return sizeof static struct switch typedef union volatile while`),
      literals: words('NULL true false'),
      types: words(C_TYPES),
      declaresType: words('struct enum union typedef'),
      capitalizedTypes: true,
    },
    cpp: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['preprocessor', /#\s*\w+/], DOUBLE_QUOTED, SINGLE_QUOTED, NUMBER, IDENT],
      keywords: words(`alignas alignof auto break case catch class const constexpr const_cast continue decltype default
        delete do dynamic_cast else enum explicit export extern for friend goto if inline mutable namespace new noexcept
        operator private protected public register reinterpret_cast return sizeof static static_assert static_cast struct
        switch template this throw try typedef typeid typename union using virtual volatile while override final`),
      literals: words('true false nullptr NULL'),
      types: words(C_TYPES + ' wchar_t char8_t char16_t char32_t string vector map'),
      declaresType: words('class struct enum union namespace'),
      capitalizedTypes: true,
    },
    objc: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['preprocessor', /#\s*\w+/], ['string', /@?"(?:[^"\\\n]|\\.)*"?/],
        ['keyword', /@\w+/], SINGLE_QUOTED, NUMBER, IDENT],
      keywords: words(`auto break case const continue default do else enum extern for goto if inline return sizeof static
        struct switch typedef union volatile while self super id instancetype nonatomic atomic strong weak copy assign
        readonly readwrite nullable nonnull`),
      literals: words('YES NO nil Nil NULL true false'),
      types: words(C_TYPES + ' BOOL SEL Class'),
      capitalizedTypes: true,
    },
    java: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['string', /"""[\s\S]*?(?:"""|$)/], DOUBLE_QUOTED, SINGLE_QUOTED,
        ['attribute', /@\w+/], NUMBER, IDENT],
      keywords: words(`abstract assert break case catch class const continue default do else enum extends final finally for
        goto if implements import instanceof interface native new package private protected public record return sealed
        static strictfp super switch synchronized this throw throws transient try var void volatile while yield permits`),
      literals: words('true false null'),
      types: words('boolean byte char short int long float double'),
      declaresType: words('class interface enum record'),
      capitalizedTypes: true,
    },
    kotlin: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['string', /"""[\s\S]*?(?:"""|$)/], DOUBLE_QUOTED, SINGLE_QUOTED,
        ['attribute', /@\w+/], NUMBER, IDENT],
      keywords: words(`abstract annotation as break by catch class companion const constructor continue crossinline data do
        else enum external final finally for fun get if import in infix init inline inner interface internal is lateinit
        noinline object open operator out override package private protected public reified return sealed set super
        suspend tailrec this throw try typealias val var vararg when where while`),
      literals: words('true false null'),
      declaresFunction: words('fun'),
      declaresType: words('class interface object typealias'),
      capitalizedTypes: true,
    },
    csharp: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['preprocessor', /#\s*\w+/], ['string', /[@$]{0,2}"(?:[^"\\\n]|\\.)*"?/],
        SINGLE_QUOTED, ['attribute', /\[\w+(?=[\](])/], NUMBER, IDENT],
      keywords: words(`abstract as async await base break case catch checked class const continue default delegate do else
        enum event explicit extern finally fixed for foreach get goto if implicit in init interface internal is lock
        namespace new operator out override params private protected public readonly record ref return sealed set sizeof
        stackalloc static struct switch this throw try typeof unchecked unsafe using var virtual void volatile when where
        while yield`),
      literals: words('true false null'),
      types: words('bool byte char decimal double float int long object sbyte short string uint ulong ushort dynamic'),
      declaresType: words('class struct interface enum record'),
      capitalizedTypes: true,
    },
    go: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['string', /`[^`]*`?/], DOUBLE_QUOTED, SINGLE_QUOTED, NUMBER, IDENT],
      keywords: words(`break case chan const continue default defer else fallthrough for func go goto if import interface
        map package range return select struct switch type var`),
      literals: words('true false nil iota'),
      types: words(`bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8
        uint16 uint32 uint64 uintptr any`),
      declaresFunction: words('func'),
      declaresType: words('type'),
    },
    rust: {
      rules: [LINE_COMMENT, BLOCK_COMMENT, ['string', /b?r#*"[\s\S]*?(?:"#*|$)/], ['string', /b?"(?:[^"\\]|\\[\s\S])*"?/],
        ['string', /b?'(?:\\.|[^\\'\n])'/], ['attribute', /'\w+/], ['attribute', /#!?\[[^\]\n]*\]?/],
        ['function', /\w+!(?=\s*[([{])/], NUMBER, IDENT],
      keywords: words(`as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move
        mut pub ref return self Self static struct super trait type unsafe use where while`),
      literals: words('true false None Some Ok Err'),
      types: words('i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str String Vec Option Result Box'),
      declaresFunction: words('fn'),
      declaresType: words('struct enum trait type impl'),
      capitalizedTypes: true,
    },
    ruby: {
      rules: [HASH_COMMENT, DOUBLE_QUOTED, SINGLE_QUOTED, ['literal', /:\w+/], ['variable', /@{1,2}\w+|\$\w+/], NUMBER,
        ['ident', /[A-Za-z_]\w*[?!]?/]],
      keywords: words(`alias and begin break case class def defined? do else elsif end ensure for if in module next not or
        redo rescue retry return self super then undef unless until when while yield require require_relative attr_accessor
        attr_reader attr_writer private protected public`),
      literals: words('true false nil'),
      declaresFunction: words('def'),
      declaresType: words('class module'),
      capitalizedTypes: true,
    },
    sql: {
      rules: [['comment', /--[^\n]*/], BLOCK_COMMENT, SINGLE_QUOTED, ['property', /"(?:[^"\n])*"?/], NUMBER, IDENT],
      keywords: words(`select from where and or not insert into values update set delete create table drop alter add column
        index view primary key foreign references join inner left right full outer cross on as group by order having limit
        offset distinct union all exists in is like between case when then else end asc desc with returning default
        constraint unique check if begin commit rollback transaction`),
      literals: words('null true false'),
      types: words('int integer bigint smallint decimal numeric float real double varchar char text date time timestamp boolean blob json uuid serial'),
      caseInsensitive: true,
    },
    yaml: {
      rules: [['comment', /(?<=^|\s)#[^\n]*/], ['property', /[\w.-]+(?=:(?:\s|$))/], DOUBLE_QUOTED, SINGLE_QUOTED,
        ['keyword', /^---$/m], NUMBER, IDENT],
      keywords: words(''),
      literals: words('true false null yes no on off'),
    },
    diff: {
      rules: [['inserted', /^\+[^\n]*/m], ['deleted', /^-[^\n]*/m], ['attribute', /^@@[^\n]*/m], ['comment', /^(?:diff|index) [^\n]*/m]],
    },
  };

  const ALIASES = {
    py: 'python', python3: 'python',
    js: 'javascript', jsx: 'javascript', mjs: 'javascript', cjs: 'javascript', node: 'javascript',
    typescript: 'javascript', ts: 'javascript', tsx: 'javascript',
    jsonc: 'json', json5: 'json',
    sh: 'shell', bash: 'shell', zsh: 'shell', console: 'shell', 'shell-session': 'shell', fish: 'shell',
    xml: 'html', svg: 'html', plist: 'html', xhtml: 'html', vue: 'html',
    scss: 'css', less: 'css', sass: 'css',
    h: 'c', 'c++': 'cpp', cc: 'cpp', cxx: 'cpp', hpp: 'cpp',
    'objective-c': 'objc', objectivec: 'objc', m: 'objc', mm: 'objc',
    kt: 'kotlin', kts: 'kotlin', cs: 'csharp', 'c#': 'csharp', golang: 'go', rs: 'rust', rb: 'ruby',
    psql: 'sql', mysql: 'sql', sqlite: 'sql', yml: 'yaml', patch: 'diff',
  };

  // TypeScript adds a few keywords and types to JavaScript.
  const TYPESCRIPT_EXTRAS = words(`interface type enum implements private public protected readonly declare namespace abstract
    keyof infer is satisfies`);
  const TYPESCRIPT_TYPES = words('string number boolean any unknown never object symbol bigint void');

  // Compile each language's rules once, with the sticky flag so matching starts exactly at the cursor.
  for (const def of Object.values(LANGUAGES)) {
    def.rules = def.rules.map(([type, pattern]) => [type, re(pattern)]);
  }

  function language(name) {
    const key = String(name).trim().toLowerCase();
    const id = ALIASES[key] ?? key;
    const def = LANGUAGES[id];
    if (!def) return null;
    if (['typescript', 'ts', 'tsx'].includes(key)) {
      return { ...def, keywords: new Set([...def.keywords, ...TYPESCRIPT_EXTRAS]), types: TYPESCRIPT_TYPES };
    }
    return def;
  }

  function classify(def, word, code, start, tokens) {
    const key = def.caseInsensitive ? word.toLowerCase() : word;
    if (def.keywords?.has(key)) return 'keyword';
    if (def.literals?.has(key)) return 'literal';

    // The name after `func`, `def`, `class` etc. is a declaration.
    const previous = tokens[tokens.length - 1];
    if (previous?.type === 'keyword' && /^\s+$/.test(code.slice(previous.end, start))) {
      const keyword = code.slice(previous.start, previous.end);
      if (def.declaresFunction?.has(keyword)) return 'function';
      if (def.declaresType?.has(keyword)) return 'type';
    }
    if (def.types?.has(key)) return 'type';
    if (def.capitalizedTypes && /^[A-Z]/.test(word) && /[a-z]/.test(word)) return 'type';

    const after = code.slice(start + word.length).match(/^\s*(\S)/);
    if (after?.[1] === '(') return 'function';

    // Shell: the first word of a command.
    if (def.commandWords) {
      const line = code.slice(code.lastIndexOf('\n', start - 1) + 1, start);
      const before = line.match(/(\S*)\s*$/)[1];
      if (before === '' || /[|;&(]$/.test(before) || before === '$' || before === '%') return 'function';
    }
    return null;
  }

  // Returns [{ start, end, type }] for the code, using the given language definition.
  function tokenize(code, def) {
    const tokens = [];
    let pos = 0;
    scanning: while (pos < code.length) {
      for (const [type, pattern] of def.rules) {
        pattern.lastIndex = pos;
        const match = pattern.exec(code);
        if (!match || !match[0].length) continue;
        const end = pos + match[0].length;
        const tokenType = type === 'ident' ? classify(def, match[0], code, pos, tokens) : type;
        if (tokenType) tokens.push({ start: pos, end, type: tokenType });
        pos = end;
        continue scanning;
      }
      pos++;
    }
    return tokens;
  }

  const TYPES = ['comment', 'string', 'number', 'keyword', 'literal', 'type', 'function', 'attribute', 'preprocessor',
    'property', 'variable', 'inserted', 'deleted'];

  return { language, tokenize, TYPES };
})();
