import SwiftUI

@main
struct MarkdownStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var guideNavigation = GuideNavigation()

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            FormatCommands()
            FindCommands()
            ScrollCommands()
            OpenCommands()
            HelpCommands(navigation: guideNavigation)
        }

        Window("Markdown Studio Guide", id: GuideView.windowID) {
            GuideView(navigation: guideNavigation)
        }
        .defaultSize(width: 960, height: 700)
    }
}
