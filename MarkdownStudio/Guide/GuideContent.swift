import Foundation

struct GuideSection: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let markdown: String
}

struct GuideChapter: Identifiable {
    let id: String
    let title: String
    let sections: [GuideSection]
}

/// The content of the Help ▸ Markdown Studio Guide window, written in Markdown.
enum GuideContent {
    static let welcomeID = "welcome"
    static let findID = "find-replace"
    static let syntaxID = "syntax"
    static let shortcutsID = "shortcuts"

    static func section(id: GuideSection.ID?) -> GuideSection? {
        chapters.lazy.flatMap(\.sections).first { $0.id == id }
    }

    static let chapters: [GuideChapter] = [
        GuideChapter(id: "app", title: "Using Markdown Studio", sections: [
            welcome, documents, panes, toolbar, outline, findReplace, scrolling, copyPaste, shortcuts, tips,
        ]),
        GuideChapter(id: "markdown", title: "Markdown Syntax", sections: [
            syntax, headings, paragraphs, emphasis, lists, links, images, code, quotes, tables, rules, html, escaping,
        ]),
    ]

    // MARK: - Using Markdown Studio

    static let welcome = GuideSection(id: welcomeID, title: "Welcome", symbol: "hand.wave", markdown: #"""
    # Welcome to Markdown Studio

    Markdown Studio is a side-by-side editor for **Markdown** (`.md`) files. Every document window has two panes:

    - **Markdown** (left): the plain-text source, exactly as it's saved to disk.
    - **Rendered** (right): the formatted document, which you can also edit directly, like a word processor.

    Edit either side and the other one updates automatically. Use whichever suits the moment: type Markdown when you know the syntax, or use the rendered side and its toolbar when you'd rather click a button.

    ## Getting started

    1. Choose **File ▸ New** (⌘N) to create a document, or **File ▸ Open…** (⌘O) to open an existing `.md` file.
    2. Start typing in either pane.
    3. Choose **File ▸ Save** (⌘S) to name and save the document. After that, changes are saved automatically.

    ## Where to go next

    - **The Two Panes** explains how editing and syncing work.
    - **Formatting Toolbar** describes every button above the rendered view.
    - **Markdown Syntax** (in the sidebar) is a complete reference with examples.

    > Tip: Press ⌘? at any time to open this guide, or use the search field in the sidebar to find a topic.
    """#)

    static let documents = GuideSection(id: "documents", title: "Working with Documents", symbol: "doc.text", markdown: #"""
    # Working with Documents

    Markdown Studio is a standard Mac document app, so the usual File menu commands all work.

    ## Opening files

    - **File ▸ Open…** (⌘O) opens Markdown files (`.md`, `.markdown`, `.mdown`, `.mkd`) and plain-text files.
    - Drag a file onto the Markdown Studio icon in the Dock or Finder.
    - In Finder, Control-click a file and choose **Open With ▸ Markdown Studio**.
    - **File ▸ Open Recent** lists documents you've used recently.

    ## Saving

    - New documents are saved with the `.md` extension in UTF-8.
    - Once a document has been saved, Markdown Studio saves your changes automatically as you work.
    - **File ▸ Duplicate** (⇧⌘S) makes a copy; **File ▸ Rename…** and **File ▸ Move To…** work as in other Mac apps.
    - **File ▸ Revert To ▸ Browse All Versions…** lets you go back to an earlier version of the document.

    ## Multiple documents: tabs or windows

    When a document window is already open, **File ▸ Open Documents In** decides where the next document goes:

    | Choice | What happens |
    | --- | --- |
    | Ask Each Time | You're asked whether to open it in a **New Tab** or a **New Window**. Tick **Always do this** to stop being asked. |
    | New Tab | It opens as a tab in the front window. |
    | New Window | It opens in its own window. |
    | System Setting | It follows "Prefer tabs when opening documents" in System Settings ▸ Desktop & Dock. |

    To choose for just one file, use **File ▸ Open in New Tab…** (⌥⌘O) or **File ▸ Open in New Window…**.

    Windows reopened when Markdown Studio starts keep their previous arrangement. You can always rearrange later with **Window ▸ Merge All Windows**, or by dragging a tab out of the tab bar.
    """#)

    static let panes = GuideSection(id: "panes", title: "The Two Panes", symbol: "rectangle.split.2x1", markdown: #"""
    # The Two Panes

    ## Markdown pane (left)

    The left pane shows the document's source text. It's a plain-text editor with a monospaced font, and smart quotes and automatic dash substitution are turned off so your Markdown syntax is never altered. The header shows a live word count.

    - **Find & Replace:** press ⌘F (see **Find & Replace**).
    - **Undo:** ⌘Z and ⇧⌘Z undo and redo, including changes that came from the rendered pane.

    ## Rendered pane (right)

    The right pane shows the document formatted: headings, lists, tables, code blocks and so on. It's fully editable:

    - Click anywhere and type, just like in a word processor.
    - Use the **formatting toolbar** above it, or the **Format** menu, to apply styles.
    - Click a checklist box to tick it off.
    - ⌘-click a link to open it in your browser.
    - Press **Tab** in a list item to indent it (making a nested list), and **⇧Tab** to outdent it.
    - Press **Return** inside a code block to start a new line in the code block.

    ## How syncing works

    - When you type in the **Markdown** pane, the rendered pane updates as you type.
    - When you edit in the **rendered** pane, Markdown Studio converts the result back to Markdown and updates the left pane about a tenth of a second after you stop typing.

    When the source is regenerated from the rendered pane, it's written in a consistent style. For example, reference-style links become inline links. Editing only in the Markdown pane never reformats anything.

    ## Resizing

    Drag the divider between the panes to give either side more room.

    ## Zooming

    Make the text in both panes larger or smaller with the zoom buttons (small and large **A**) in the window toolbar, or with **View ▸ Zoom In** (⌘+), **Zoom Out** (⌘−) and **Actual Size** (⌘0). The zoom runs from 70% to 300%, applies to every document and this guide, and is remembered the next time you open the app. Point at a zoom button to see the current zoom.

    ## File path in the title

    The window title and tabs show where the file is, as well as its name: as much of the folder path as fits, shortened from the front, for example `…/Projects/Notes/todo.md`. Your home folder is shown as `~`.

    To show just the file name, click the **folder** button in the window toolbar (it's highlighted while the path is shown), or choose **View ▸ Show File Path in Title**. The setting is remembered.

    ## Dark Mode

    Choose how Markdown Studio looks with the Dark Mode button in the window toolbar (it shows a moon, sun or half-filled circle), or with **View ▸ Dark Mode**:

    | Choice | Appearance |
    | --- | --- |
    | On | Always dark |
    | System Default | Follows the setting in System Settings ▸ Appearance |
    | Off | Always light |

    The choice applies to every window, including this guide, and is remembered the next time you open the app.

    ## Scrolling together

    Click the **Link Scrolling** button in the window toolbar to keep both panes aligned as you scroll. See **Linked Scrolling**.
    """#)

    static let toolbar = GuideSection(id: "toolbar", title: "Formatting Toolbar", symbol: "textformat", markdown: #"""
    # Formatting Toolbar

    The toolbar above the rendered pane applies formatting to the selection, or to the paragraph containing the insertion point. Buttons light up to show the formatting at the current position. Every toolbar command is also in the **Format** menu.

    ## Text style

    The pop-up menu at the left sets the style of the current paragraph:

    | Style | Markdown | Shortcut |
    | --- | --- | --- |
    | Body | plain paragraph | ⌥⌘0 |
    | Title 1 | `# Title` | ⌥⌘1 |
    | Title 2 | `## Title` | ⌥⌘2 |
    | Title 3 | `### Title` | ⌥⌘3 |
    | Title 4 | `#### Title` | ⌥⌘4 |
    | Title 5 | `##### Title` | ⌥⌘5 |
    | Title 6 | `###### Title` | ⌥⌘6 |
    | Code Block | fenced with three backticks | — |

    Choosing a title style a second time turns the paragraph back into body text.

    ## Character formatting

    | Button | Does | Markdown | Shortcut |
    | --- | --- | --- | --- |
    | **B** | Bold | `**text**` | ⌘B |
    | *I* | Italic | `*text*` | ⌘I |
    | ~~S~~ | Strikethrough | `~~text~~` | ⇧⌘X |
    | `</>` | Inline code | `` `text` `` | ⌥⌘C |

    With no text selected, Inline Code inserts the placeholder `code` for you to type over. Click it again inside code to remove the code formatting.

    ## Lists

    - **Bulleted List** (⇧⌘7): click the main part of the button to turn a bulleted list on or off. Click the arrow to choose a **bullet style**:
      - **• Disc**: written as `-` in Markdown
      - **◦ Circle**: written as `*`
      - **▪ Square**: written as `+`
    - **Numbered List** (⇧⌘9): turns a numbered list on or off.
    - **Checklist** (⇧⌘L): adds tick boxes to the list items, or removes them.

    The bullet style is stored as the list's Markdown bullet character, so it's saved with your file. Other Markdown apps usually show all three styles as ordinary bullets.

    ## Blocks and links

    | Button | Does | Shortcut |
    | --- | --- | --- |
    | Quote | Turns the paragraph (or the whole list) into a block quote, or back | ⌘' |
    | Code Block | Turns the paragraph into a code block, or back | — |
    | Link | Adds, edits or removes a link | ⌘K |
    | Horizontal Rule | Inserts a divider line | — |
    | Eraser | Clears character formatting and makes the paragraph body text | — |

    To add a link, select the text you want to link, click **Link** (or press ⌘K), type the address and press Return. With nothing selected, the address itself is inserted as the link text. To change or remove an existing link, place the insertion point inside it and click **Link** again.

    > The Format menu shortcuts work while you're editing in the rendered pane. In the Markdown pane, type the syntax directly (see **Markdown Syntax**).
    """#)

    static let outline = GuideSection(id: "outline", title: "Collapsing Sections", symbol: "list.bullet.indent", markdown: ##"""
    # Collapsing Sections

    In the rendered pane, every title (Title 1 to Title 6) starts a section that you can fold away. A section is everything after the title, up to the next title of the same or a higher level. So folding a Title 2 also hides the Title 3s inside it.

    Folding only changes what you see. Your Markdown is never changed, and nothing is saved in the file.

    ## Folding one section

    Move the pointer over a title and click the arrow that appears in the margin to its left:

    | Arrow | Meaning |
    | --- | --- |
    | Pointing down | The section is fully open. Click to fold it. |
    | Pointing right, gray title | The section is folded. Click to open it, including all its sub-sections. |
    | Pointing right, normal title | Only the section's sub-titles are shown (an outline level). Click to open it fully. |

    ## Showing only titles

    Click **Outline** in the formatting toolbar, or choose **View ▸ Outline**, to turn the document into an outline:

    | Choice | Shows | Shortcut |
    | --- | --- | --- |
    | Show Everything | The whole document | ⌃⌘0 |
    | Title 1 Only | Only Title 1s | ⌃⌘1 |
    | Titles 1–2 | Title 1s and Title 2s | ⌃⌘2 |
    | Titles 1–3 … 1–6 | Titles down to that level | ⌃⌘3 … ⌃⌘6 |
    | Collapse All Sections | Only the top-level titles, all folded | — |
    | Expand All Sections | The whole document | — |

    In an outline, click a title's arrow to open that section completely, with all its sub-sections, and read it. The **Outline** button is highlighted while part of the document is hidden.

    ## Good to know

    - When you edit the Markdown pane, folded sections stay folded. If you rename a folded title in the Markdown pane, its section opens again.
    - **Find** opens any folded section that contains the current match.
    - Linked scrolling skips over folded sections.
    - Be careful when selecting across a folded section and pressing Delete in the rendered pane: the hidden text inside it is deleted too. You can undo with ⌘Z.
    """##)

    static let findReplace = GuideSection(id: findID, title: "Find & Replace", symbol: "magnifyingglass", markdown: ##"""
    # Find & Replace

    Press **⌘F** to show the find bar at the top of the window, and press **⌘F** again to hide it. **⌥⌘F** shows it with the replace field, and hides it again the same way. You can also click the magnifying glass in the toolbar to show or hide it.

    ## Finding text

    1. Type what you're looking for. Every match is highlighted, and the current match is shown in a stronger yellow.
    2. Press **Return** (or ⌘G) to go to the next match, and **⇧Return** (or ⇧⌘G) to go to the previous one. You can also use the arrow buttons.
    3. The field shows where you are, such as **3 of 12**.
    4. Press **Esc** or click **Done** to close the find bar and clear the highlights.

    To search for text you've already selected, press **⌘E** (Use Selection for Find).

    ## Which pane is searched

    The **Markdown / Rendered** switch in the find bar chooses where to search. It follows the pane you last clicked in, and you can change it at any time.

    | Searching | Finds | Example |
    | --- | --- | --- |
    | Markdown | The source text, including syntax | `**` finds every bold marker |
    | Rendered | The text as displayed | `bold text` finds it even if only part is **bold** |

    Searching the rendered text is usually best for prose. Searching the Markdown is best for syntax and for regular expressions over the raw text.

    ## Search options

    Click the magnifying glass at the left of the search field for these options:

    | Option | What it does |
    | --- | --- |
    | Match Case | Only matches the same capitalization. Off by default. |
    | Regular Expression | Treats the search as a pattern (see below). |
    | Wrap Around | Continues from the start after the last match. On by default. |
    | Contains | Matches the text anywhere, even inside words. |
    | Starts With | Matches only at the start of a word. |
    | Whole Word | Matches only complete words: `cat` doesn't match `concatenate`. |
    | Ends With | Matches only at the end of a word. |

    ## Replacing

    1. Choose **Replace** in the find bar (or press ⌥⌘F).
    2. Type the replacement text.
    3. Click **Replace** (or press Return in the replace field) to replace the current match and move to the next one. Click **Replace All** to replace every match at once.

    Replacements can be undone with ⌘Z. A Replace All in the Markdown pane is undone in one step.

    > Text inside embedded HTML blocks is found in the rendered pane, but can only be replaced in the Markdown pane.

    ## Regular expressions

    With **Regular Expression** turned on, the search is a pattern. Some common pieces:

    | Pattern | Matches |
    | --- | --- |
    | `.` | any character |
    | `\d` | a digit |
    | `\w` | a letter, digit or underscore |
    | `\s` | a space, tab or line break |
    | `[abc]` | any one of a, b or c |
    | `a+` | one or more a's |
    | `a*` | zero or more a's |
    | `a?` | an optional a |
    | `^` / `$` | the start / end of a line (Markdown pane) |
    | `(…)` | a group you can reuse in the replacement |
    | `a\|b` | a or b |

    In the replacement, `$1`, `$2` and so on insert what each group matched, and `$0` inserts the whole match.

    ### Examples

    | Find | Replace | Effect |
    | --- | --- | --- |
    | `(\w+), (\w+)` | `$2 $1` | "Smith, Jo" → "Jo Smith" |
    | `^#{3} ` | `## ` | Turns Title 3 headings into Title 2 (Markdown pane) |
    | `\s+$` | *(empty)* | Removes trailing spaces (Markdown pane) |
    | `colou?r` | `color` | Standardizes spelling |
    """##)

    static let scrolling = GuideSection(id: "scrolling", title: "Linked Scrolling", symbol: "arrow.up.and.down.circle", markdown: ##"""
    # Linked Scrolling

    The **Link Scrolling** button in the window toolbar controls how the two panes scroll.

    | Button | Mode | Behavior |
    | --- | --- | --- |
    | Highlighted | Linked | Scrolling either pane scrolls the other to the same place in the document. |
    | Not highlighted | Independent | Each pane scrolls on its own. |

    Click the button (or press ⌥⌘L) to switch between the two modes. Your choice is remembered for all documents.

    ## Choosing which pane to align to

    When you turn linking on, one pane jumps to match the other. Choose which one leads from the small arrow menu next to the button:

    - **Markdown Pane:** the rendered pane moves to match the Markdown pane.
    - **Rendered Pane:** the Markdown pane moves to match the rendered pane.

    So you can scroll each pane on its own to compare different parts of the document, then click the button to bring the other pane back to the one you care about.

    ## Aligning once

    To line the panes up without linking them, choose **Align Rendered to Markdown Now** or **Align Markdown to Rendered Now** from the arrow menu. Both are also in the **View** menu.

    > A short document may not fill the rendered pane, so there's little or nothing for it to scroll. The panes follow each other as far as each can scroll.

    ## How alignment works

    Markdown Studio knows which source line each heading, paragraph, list item, table and code block came from, and lines them up. Between those points it estimates the position, so long paragraphs or tables can be slightly offset until the next block lines up.

    While linked, the rendered pane follows along as you type in the Markdown pane.
    """##)

    static let copyPaste = GuideSection(id: "copy-paste", title: "Copy & Paste", symbol: "doc.on.clipboard", markdown: #"""
    # Copy & Paste

    Copy, cut and paste work in both panes with the usual shortcuts (⌘C, ⌘X, ⌘V).

    ## Copying from the rendered pane

    Copying from the rendered pane puts **two versions** on the clipboard:

    - **Formatted text** for apps that support it, such as Mail, Pages or Notes.
    - **Markdown** as plain text. Paste into the Markdown pane, or any plain-text editor, and you get the Markdown syntax, such as `**bold**` or `- list item`.

    Formatting is kept even when you copy only part of it. For example, copying half of a bold word gives you that half, still bold.

    ## Pasting into the rendered pane

    - **Formatted text** (for example from Safari or Pages) keeps its formatting: bold, italic, links, headings, lists and tables. When it's saved, it's converted to Markdown.
    - **Plain text** is read as Markdown. Copy `**hello**` from the Markdown pane, paste it into the rendered pane, and you get **hello** in bold.
    - Inside a code block, everything is pasted as plain text, exactly as copied.

    ## Pasting into the Markdown pane

    The Markdown pane is plain text, so anything you paste arrives as plain text. Copy from the rendered pane to get Markdown syntax.
    """#)

    static let shortcuts = GuideSection(id: shortcutsID, title: "Keyboard Shortcuts", symbol: "keyboard", markdown: #"""
    # Keyboard Shortcuts

    ## Documents

    | Action | Shortcut |
    | --- | --- |
    | New document | ⌘N |
    | Open | ⌘O |
    | Open in new tab | ⌥⌘O |
    | Save | ⌘S |
    | Duplicate | ⇧⌘S |
    | Close window | ⌘W |
    | Open this guide | ⌘? |

    ## Editing (both panes)

    | Action | Shortcut |
    | --- | --- |
    | Undo / Redo | ⌘Z / ⇧⌘Z |
    | Cut / Copy / Paste | ⌘X / ⌘C / ⌘V |
    | Select All | ⌘A |

    ## Find & Replace

    | Action | Shortcut |
    | --- | --- |
    | Show or hide Find | ⌘F |
    | Show or hide Find and Replace | ⌥⌘F |
    | Find Next / Previous | ⌘G / ⇧⌘G (or Return / ⇧Return in the find field) |
    | Use Selection for Find | ⌘E |
    | Close the find bar | Esc |

    ## View

    | Action | Shortcut |
    | --- | --- |
    | Zoom in | ⌘+ (or ⌘=) |
    | Zoom out | ⌘− |
    | Actual size | ⌘0 |
    | Link or unlink scrolling | ⌥⌘L |

    ## Formatting (rendered pane)

    | Action | Shortcut |
    | --- | --- |
    | Bold | ⌘B |
    | Italic | ⌘I |
    | Strikethrough | ⇧⌘X |
    | Inline code | ⌥⌘C |
    | Link | ⌘K |
    | Body text | ⌥⌘0 |
    | Title 1 – Title 6 | ⌥⌘1 – ⌥⌘6 |
    | Bulleted list | ⇧⌘7 |
    | Numbered list | ⇧⌘9 |
    | Checklist | ⇧⌘L |
    | Block quote | ⌘' |
    | Show everything | ⌃⌘0 |
    | Show titles 1 to N | ⌃⌘1 – ⌃⌘6 |
    | Indent / outdent list item | Tab / ⇧Tab |
    """#)

    static let tips = GuideSection(id: "tips", title: "Tips & Limitations", symbol: "lightbulb", markdown: #"""
    # Tips & Limitations

    ## Tips

    - **Learn Markdown by watching.** Format something with the toolbar and watch the Markdown pane to see the syntax it produces.
    - **Paste Markdown from elsewhere** (a README, a chat message) into the rendered pane to see it formatted right away.
    - **Open a link** in your browser by ⌘-clicking it in the rendered pane. A plain click just places the insertion point, so you can edit the link text.

    ## Limitations

    - **The source may be reformatted when you edit the rendered pane.** For example, `__bold__` becomes `**bold**` and reference-style links become inline links. The document looks the same; only the Markdown is written differently.
    - **Embedded HTML blocks** are shown rendered but can only be edited in the Markdown pane. They're always kept exactly as you wrote them.
    - **Images with relative paths** (like `images/photo.png`) aren't shown in the rendered pane. Images from web addresses (`https://…`) are.
    - **Footnotes, math and diagrams** aren't rendered. Their source text is shown as-is.
    """#)

    // MARK: - Markdown Syntax

    static let syntax = GuideSection(id: syntaxID, title: "Syntax Overview", symbol: "list.bullet.rectangle", markdown: #"""
    # Markdown Syntax Overview

    Markdown is a simple way to format plain text with punctuation characters. It was designed to be readable as-is, so a Markdown file looks good even before it's rendered. Markdown Studio supports **CommonMark** plus the popular **GitHub-Flavored Markdown** extensions: tables, strikethrough, checklists and automatic links.

    ## Cheat sheet

    | You type | You get |
    | --- | --- |
    | `# Title` | Title 1 heading |
    | `## Section` | Title 2 heading |
    | `**bold**` | **bold** |
    | `*italic*` | *italic* |
    | `~~strike~~` | ~~strike~~ |
    | `` `code` `` | `code` |
    | `[link](https://apple.com)` | [link](https://apple.com) |
    | `![alt text](image.png)` | an image |
    | `- item` | bulleted list item |
    | `1. item` | numbered list item |
    | `- [ ] task` | checklist item |
    | `> quote` | block quote |
    | `---` | horizontal rule |

    ## Blocks

    A Markdown document is made of **blocks**: paragraphs, headings, lists, quotes, code blocks, tables and rules. Separate blocks with a **blank line**:

    ~~~markdown
    # A heading

    A paragraph of text.

    - A list
    - with two items
    ~~~

    Choose a topic in the sidebar for the full details on each element.
    """#)

    static let headings = GuideSection(id: "headings", title: "Headings", symbol: "textformat.size", markdown: #"""
    # Headings

    Start a line with one to six `#` characters, then a space. The number of `#` characters sets the level. In the toolbar, these are **Title 1** to **Title 6**.

    ~~~markdown
    # Title 1
    ## Title 2
    ### Title 3
    #### Title 4
    ##### Title 5
    ###### Title 6
    ~~~

    ## Result

    ### Title 3

    #### Title 4

    ##### Title 5

    ###### Title 6

    ## Alternative style

    You can also underline a line with `=` characters for Title 1, or `-` characters for Title 2:

    ~~~markdown
    Title 1
    =======

    Title 2
    -------
    ~~~

    ## Notes

    - The space after `#` is required: `#hashtag` is ordinary text.
    - Optional closing `#` characters are ignored: `## Title ##`.
    - Headings can contain inline formatting: `## The *new* version`.
    """#)

    static let paragraphs = GuideSection(id: "paragraphs", title: "Paragraphs & Line Breaks", symbol: "paragraphsign", markdown: #"""
    # Paragraphs & Line Breaks

    ## Paragraphs

    A paragraph is one or more lines of text. Separate paragraphs with a **blank line**.

    ~~~markdown
    This is the first paragraph.

    This is the second paragraph.
    ~~~

    ## Line wrapping

    A single line break inside a paragraph is treated as a space, so you can wrap long lines in the source without affecting the result:

    ~~~markdown
    These two lines
    become one line when rendered.
    ~~~

    These two lines
    become one line when rendered.

    ## Hard line breaks

    To force a line break inside a paragraph, end the line with a **backslash** `\` or with **two or more spaces**:

    ~~~markdown
    Roses are red,\
    Violets are blue.
    ~~~

    Roses are red,\
    Violets are blue.

    In the rendered pane, press ⇧Return to insert a line break.
    """#)

    static let emphasis = GuideSection(id: "emphasis", title: "Bold, Italic & Strikethrough", symbol: "bold.italic.underline", markdown: #"""
    # Bold, Italic & Strikethrough

    | Style | Markdown | Alternative | Result |
    | --- | --- | --- | --- |
    | Bold | `**text**` | `__text__` | **text** |
    | Italic | `*text*` | `_text_` | *text* |
    | Bold italic | `***text***` | `___text___` | ***text*** |
    | Strikethrough | `~~text~~` | | ~~text~~ |

    ## Combining styles

    Styles can be nested:

    ~~~markdown
    **Bold with *italic* inside** and ~~struck **bold**~~.
    ~~~

    **Bold with *italic* inside** and ~~struck **bold**~~.

    ## Notes

    - There must be no space just inside the markers: `** text **` is not bold.
    - Underscores inside words are left alone, so `snake_case_name` stays as it is. Use `*` to emphasize part of a word: `un*frigging*believable`.
    - A lone `*` surrounded by spaces, as in `2 * 3`, is just an asterisk.
    """#)

    static let lists = GuideSection(id: "lists", title: "Lists & Checklists", symbol: "list.bullet", markdown: #"""
    # Lists & Checklists

    ## Bulleted lists

    Start each item with `-`, `*` or `+` followed by a space:

    ~~~markdown
    - Apples
    - Oranges
    - Pears
    ~~~

    - Apples
    - Oranges
    - Pears

    ## Bullet styles

    Markdown Studio shows each bullet character with its own style, which you can also choose from the toolbar:

    ~~~markdown
    - Disc

    * Circle

    + Square
    ~~~

    - Disc

    * Circle

    + Square

    Changing the bullet character starts a new list. Other Markdown apps usually show all three as ordinary bullets.

    ## Numbered lists

    Start each item with a number followed by `.` or `)`. The list starts from the first number you use, and later numbers don't matter:

    ~~~markdown
    1. Preheat the oven
    2. Mix the ingredients
    3. Bake for 20 minutes
    ~~~

    1. Preheat the oven
    2. Mix the ingredients
    3. Bake for 20 minutes

    ## Nested lists

    Indent an item so it lines up with the text of the item above it (two spaces after `-`, three after `1.`):

    ~~~markdown
    1. Fruit
       - Apples
       - Pears
    2. Vegetables
       - Carrots
    ~~~

    1. Fruit
       - Apples
       - Pears
    2. Vegetables
       - Carrots

    In the rendered pane, press **Tab** to indent an item and **⇧Tab** to outdent it.

    ## Checklists

    Add `[ ]` (unchecked) or `[x]` (checked) after the bullet:

    ~~~markdown
    - [x] Write the draft
    - [ ] Check the spelling
    - [ ] Publish
    ~~~

    - [x] Write the draft
    - [ ] Check the spelling
    - [ ] Publish

    Click a box in the rendered pane to tick it off, and the Markdown updates.

    ## Tight and loose lists

    If list items are separated by blank lines, the list is **loose** and each item is spaced like a paragraph. Without blank lines, the list is **tight**.

    ## Multiple paragraphs in an item

    Indent extra paragraphs, code blocks or quotes to line up with the item's text:

    ~~~markdown
    - First item.

      A second paragraph in the first item.

    - Second item.
    ~~~
    """#)

    static let links = GuideSection(id: "links", title: "Links", symbol: "link", markdown: #"""
    # Links

    ## Inline links

    Put the link text in square brackets, followed by the address in parentheses:

    ~~~markdown
    Visit [Apple](https://www.apple.com) for more.
    ~~~

    Visit [Apple](https://www.apple.com) for more.

    ## Link titles

    Add a title in quotes after the address. It appears as a tooltip:

    ~~~markdown
    [Apple](https://www.apple.com "Apple's website")
    ~~~

    ## Automatic links

    Web addresses starting with `http://`, `https://` or `www.` become links automatically. You can also wrap any address in angle brackets:

    ~~~markdown
    https://www.apple.com
    <mailto:someone@example.com>
    ~~~

    ## Reference links

    Keep long addresses out of your text by giving them a label, defined anywhere in the document:

    ~~~markdown
    Read the [CommonMark spec][spec] or the [GitHub guide][].

    [spec]: https://spec.commonmark.org "CommonMark"
    [GitHub guide]: https://github.github.com/gfm/
    ~~~

    Labels aren't case-sensitive. Definitions don't appear in the rendered document.

    ## Links to sections and files

    Addresses can be relative, such as `[Setup](docs/setup.md)` or `[Top](#title)`. They work when the file is viewed in a place that supports them, such as GitHub.

    ## In the rendered pane

    Select text and press ⌘K (or click the **Link** button) to add a link. Place the insertion point in a link and press ⌘K to change or remove it.
    """#)

    static let images = GuideSection(id: "images", title: "Images", symbol: "photo", markdown: #"""
    # Images

    Images are written like links, with an exclamation mark `!` in front. The text in brackets is the **alt text**, which describes the image for screen readers and is shown if the image can't be loaded.

    ~~~markdown
    ![A sunset over the sea](https://example.com/sunset.jpg)
    ~~~

    ## Title

    ~~~markdown
    ![Logo](logo.png "Company logo")
    ~~~

    ## Linked images

    Put an image inside a link to make it clickable:

    ~~~markdown
    [![Build status](https://example.com/badge.svg)](https://example.com/builds)
    ~~~

    ## Reference images

    ~~~markdown
    ![Diagram][diagram]

    [diagram]: https://example.com/diagram.png
    ~~~

    ## Notes

    - Markdown Studio shows images from web addresses. Images with relative file paths, like `images/photo.png`, are kept in the Markdown but aren't shown in the rendered pane.
    - To control an image's size, use HTML instead: `<img src="photo.png" width="300">`.
    """#)

    static let code = GuideSection(id: "code", title: "Code", symbol: "chevron.left.forwardslash.chevron.right", markdown: #"""
    # Code

    ## Inline code

    Wrap text in backticks to show it in a monospaced font. Markdown inside code is not formatted:

    ~~~markdown
    Use the `print()` function. `**not bold**`
    ~~~

    Use the `print()` function. `**not bold**`

    To include a backtick in inline code, wrap it in double backticks: ``` `` a `tick` here `` ```.

    ## Code blocks

    Put three backticks (or three tildes `~~~`) on the lines before and after the code:

    ~~~markdown
    ```
    let greeting = "Hello"
    print(greeting)
    ```
    ~~~

    ```
    let greeting = "Hello"
    print(greeting)
    ```

    ## Language names

    Write the language's name after the opening backticks. Many Markdown apps, such as GitHub, use it to color the code:

    ~~~markdown
    ```swift
    struct Point { var x, y: Double }
    ```
    ~~~

    ## Indented code

    Lines indented by four spaces also form a code block:

    ~~~markdown
        This is a code block.
    ~~~

    Markdown Studio converts indented code blocks to backtick blocks if you edit them in the rendered pane.

    ## Showing backticks in a code block

    Use more backticks for the outer fence than appear inside it, or use tildes, as this guide does.
    """#)

    static let quotes = GuideSection(id: "quotes", title: "Block Quotes", symbol: "text.quote", markdown: #"""
    # Block Quotes

    Start a line with `>` to quote it:

    ~~~markdown
    > The best way to predict the future is to invent it.
    ~~~

    > The best way to predict the future is to invent it.

    ## Multiple paragraphs

    Put `>` on the blank line between paragraphs too:

    ~~~markdown
    > First paragraph.
    >
    > Second paragraph.
    ~~~

    > First paragraph.
    >
    > Second paragraph.

    ## Nested quotes and other elements

    Quotes can contain any Markdown, including other quotes:

    ~~~markdown
    > ## A heading
    > - A list item
    >
    > > A nested quote
    ~~~

    > ## A heading
    > - A list item
    >
    > > A nested quote
    """#)

    static let tables = GuideSection(id: "tables", title: "Tables", symbol: "tablecells", markdown: #"""
    # Tables

    Separate columns with `|` and put a line of dashes under the header row:

    ~~~markdown
    | Fruit  | Color  | Price |
    | ------ | ------ | ----- |
    | Apple  | Red    | $1    |
    | Banana | Yellow | $0.50 |
    ~~~

    | Fruit | Color | Price |
    | --- | --- | --- |
    | Apple | Red | $1 |
    | Banana | Yellow | $0.50 |

    The columns don't have to line up in the source, and the outer pipes are optional.

    ## Alignment

    Add colons to the dashes line to align a column:

    ~~~markdown
    | Left | Center | Right |
    | :--- | :----: | ----: |
    | a    | b      | c     |
    ~~~

    | Left | Center | Right |
    | :--- | :---: | ---: |
    | a | b | c |

    ## Notes

    - Cells can contain inline formatting: bold, italic, code and links.
    - To use a `|` character inside a cell, write `\|`.
    - To break a line inside a cell, use `<br>`.
    - In the rendered pane, click a cell to edit its text.
    """#)

    static let rules = GuideSection(id: "rules", title: "Horizontal Rules", symbol: "minus", markdown: #"""
    # Horizontal Rules

    A line containing three or more `-`, `*` or `_` characters becomes a dividing line:

    ~~~markdown
    ---
    ***
    ___
    ~~~

    ---

    Spaces between the characters are allowed: `- - -`.

    > Leave a blank line above `---`. Directly under a line of text, `---` turns that text into a Title 2 heading instead.
    """#)

    static let html = GuideSection(id: "html", title: "HTML", symbol: "curlybraces", markdown: #"""
    # HTML

    Markdown documents can contain blocks of HTML for things Markdown can't express, such as centered text or sized images:

    ~~~markdown
    <p align="center">
      <img src="https://example.com/logo.png" width="120">
    </p>

    <details>
    <summary>Click to expand</summary>

    Hidden content.

    </details>
    ~~~

    ## How Markdown Studio handles HTML

    - An HTML block starts with a line beginning with an HTML tag and ends at the next blank line.
    - HTML blocks are shown rendered, but you can't edit them in the rendered pane. Edit them in the Markdown pane instead. They're always saved exactly as you wrote them.
    - For safety, scripts and other active content in HTML blocks are never run.
    - In running text, `<br>` inserts a line break. Other inline HTML tags are shown as text.

    ## Comments

    HTML comments are hidden in the rendered document. Use them for notes to yourself:

    ~~~markdown
    <!-- TODO: add screenshots -->
    ~~~
    """#)

    static let escaping = GuideSection(id: "escaping", title: "Escaping Characters", symbol: "textformat.abc", markdown: ##"""
    # Escaping Characters

    To show a character that Markdown would otherwise treat as formatting, put a backslash `\` in front of it:

    ~~~markdown
    \*not italic\*  \# not a heading  1\. not a list
    ~~~

    \*not italic\*  \# not a heading  1\. not a list

    ## Characters you can escape

    | Character | Name |
    | --- | --- |
    | `\` | backslash |
    | `` ` `` | backtick |
    | `*` | asterisk |
    | `_` | underscore |
    | `{ }` `[ ]` `( )` | braces, brackets, parentheses |
    | `#` | hash |
    | `+` `-` `.` `!` | plus, minus, period, exclamation mark |
    | `\|` | pipe |
    | `< >` | angle brackets |
    | `~` | tilde |

    ## Automatic escaping

    When you type in the rendered pane, Markdown Studio adds backslashes for you wherever they're needed. For example, typing `*sale*` gives `\*sale\*` in the Markdown, so the asterisks show up as typed.
    """##)
}
