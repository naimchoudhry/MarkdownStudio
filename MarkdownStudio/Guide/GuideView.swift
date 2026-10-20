import Observation
import SwiftUI

@Observable
final class GuideNavigation {
    var selection: GuideSection.ID? = GuideContent.welcomeID
}

/// The in-app user guide, opened from the Help menu.
struct GuideView: View {
    static let windowID = "guide"

    @Bindable var navigation: GuideNavigation
    @State private var searchText = ""
    @AppStorage(ViewZoom.key) private var zoom = 1.0

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selection) {
                ForEach(GuideContent.chapters) { chapter in
                    let sections = filtered(chapter.sections)
                    if !sections.isEmpty {
                        Section(chapter.title) {
                            ForEach(sections) { section in
                                Label(section.title, systemImage: section.symbol)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search the Guide")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            let section = GuideContent.section(id: navigation.selection) ?? GuideContent.chapters[0].sections[0]
            RenderedEditorView(markdown: .constant(section.markdown), isEditable: false, zoom: zoom)
                .navigationTitle(section.title)
        }
    }

    private func filtered(_ sections: [GuideSection]) -> [GuideSection] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sections }
        return sections.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.markdown.localizedCaseInsensitiveContains(query) }
    }
}
