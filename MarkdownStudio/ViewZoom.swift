import Foundation

/// The app-wide text zoom for both panes and the guide, stored in user defaults so it's remembered.
/// Views read it with `@AppStorage(ViewZoom.key)`, which updates them when it changes.
enum ViewZoom {
    static let key = "ViewZoom"
    static let levels: [Double] = [0.7, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    /// Font size of the Markdown pane at 100%.
    static let baseSourceFontSize = 13.0

    static var current: Double {
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : 1
    }

    static var canZoomIn: Bool { current < levels.last! - 0.001 }
    static var canZoomOut: Bool { current > levels.first! + 0.001 }

    static func zoomIn() {
        set(levels.first { $0 > current + 0.001 } ?? levels.last!)
    }

    static func zoomOut() {
        set(levels.last { $0 < current - 0.001 } ?? levels.first!)
    }

    static func reset() {
        set(1)
    }

    static func percentage(_ zoom: Double) -> String {
        "\(Int((zoom * 100).rounded()))%"
    }

    private static func set(_ zoom: Double) {
        UserDefaults.standard.set(zoom, forKey: key)
    }
}
