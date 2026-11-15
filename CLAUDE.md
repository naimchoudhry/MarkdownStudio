# Markdown Studio

## Keep the docs in step with the app

Every user-visible change (new feature, changed behaviour, new shortcut, notable fix) must update all of these in the same change, before it's reported as done:

1. **Version history:** `MarkdownStudio/Guide/VersionHistory.swift`. Add the change to the newest release section, or start a new section at the top (`## 1.x — Month Year`) for a new release.
2. **App version:** before changing it, **ask the user** whether the change is:
   - a **primary** update: a new major version (e.g. 1.3 → 2.0),
   - a **secondary** update: a new minor version (e.g. 1.3 → 1.4), or
   - part of the **current** release, if it hasn't been released yet (version stays the same; add to its Version History section).

   Then set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `MarkdownStudio.xcodeproj/project.pbxproj` (both configurations). The build number goes up by one for each new version. Help ▸ Version History and About Markdown Studio read these.
3. **In-app guide:** `MarkdownStudio/Guide/GuideContent.swift`. Update the section that covers the feature, or add one (and list it in `chapters`), plus the Keyboard Shortcuts section for any new shortcut.
4. **Help menu:** `HelpCommands` in `MarkdownStudio/AppCommands.swift`, if the change adds a new guide page or help window worth linking.
5. **README:** `README.md`. Update What's new, Features, Keyboard shortcuts and How it works (including the file tree for new source files) as relevant.

Purely internal changes (refactoring, tests, build scripts) don't need these updates.

## "Create a release build"

When the user asks for a release build, do all of this:

1. **Version:** move to the next version, e.g. 1.1 → 1.2 (`MARKETING_VERSION`, and `CURRENT_PROJECT_VERSION` + 1, both configurations). No need to ask about primary/secondary for this. If the current version was never released (still being added to), check with the user whether to release it as it is or move on to the next number.
2. **Version history and README:** make sure the release's section in `VersionHistory.swift` and README's What's new are complete and dated, and that README's Features, shortcuts and How it works are current.
3. **Screenshots:** retake the README screenshots (`docs/images/`) from the new build, in light and dark mode, adding any that new features need, and update the README to use them.
4. **Videos:** re-record any demo videos the README links to, so they show the current app.
5. **Build:** build Release and install it with `./install.sh`, then verify it runs.

Take screenshots and videos with a temporary in-app harness (removed afterwards), using demo documents rather than the user's own files, and never with the user's file paths or personal details visible.
