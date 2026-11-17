import AppKit
import WebKit

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

    /// Pinching on the trackpad zooms between the smallest and largest levels, in any window that shows
    /// text (both panes, the guide, Version History). While pinching, the window's panes are only
    /// scaled as images, which is instant; the text is laid out at the new size once, when the pinch ends. It
    /// settles on a whole percentage, snapping to 100% when it's close.
    static func startPinchToZoom() {
        NSEvent.addLocalMonitorForEvents(matching: .magnify) { event in
            guard let window = event.window else { return event }
            pinch(event, in: window)
            return nil
        }
    }

    /// True during a pinch, so the panes' magnified scrolling isn't taken for the user's.
    private(set) static var isPinching = false
    private static var pinchStart = 1.0
    private static var pinchFactor = 1.0
    private static var pinchViews: [NSView] = []

    private static func pinch(_ event: NSEvent, in window: NSWindow) {
        if !isPinching || event.phase == .began {
            isPinching = true
            pinchStart = current
            pinchFactor = 1
            pinchViews = zoomableViews(in: window.contentView)
        }
        let lowest = levels.first! / pinchStart, highest = levels.last! / pinchStart
        pinchFactor = min(max(pinchFactor * (1 + event.magnification), lowest), highest)
        for view in pinchViews { magnify(view, to: pinchFactor, at: event.locationInWindow) }
        guard event.phase == .ended || event.phase == .cancelled else { return }

        let zoom = pinchStart * pinchFactor
        set(abs(zoom - 1) < 0.04 ? 1 : (zoom * 100).rounded() / 100)
        // Undo the magnification once the panes have been laid out at the new size.
        let views = pinchViews
        pinchViews = []
        Task {
            await Task.yield()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for view in views { magnify(view, to: 1, at: nil) }
            CATransaction.commit()
            try? await Task.sleep(for: .milliseconds(100))
            isPinching = false
        }
    }

    /// The Markdown panes' scroll views and the rendered panes' web views.
    private static func zoomableViews(in view: NSView?) -> [NSView] {
        guard let view else { return [] }
        if view is WKWebView { return [view] }
        if let scrollView = view as? NSScrollView, scrollView.documentView is NSTextView { return [scrollView] }
        return view.subviews.flatMap(zoomableViews)
    }

    /// Scales what `view` shows around the pinch, without changing the view itself (or WebKit's or the
    /// text view's own zoom), so nothing is left over afterwards. Scaling to 1 removes it.
    private static func magnify(_ view: NSView, to factor: Double, at windowPoint: NSPoint?) {
        guard let layer = view.layer else { return }
        layer.masksToBounds = true
        guard factor != 1, let windowPoint else {
            layer.sublayerTransform = CATransform3DIdentity
            return
        }
        // Scale about the pinch, or the nearest point to it in a pane it's not over. The sublayer
        // transform applies about the layer's anchor point.
        var viewPoint = view.convert(windowPoint, from: nil)
        viewPoint.x = min(max(viewPoint.x, view.bounds.minX), view.bounds.maxX)
        viewPoint.y = min(max(viewPoint.y, view.bounds.minY), view.bounds.maxY)
        let point = view.convertToLayer(viewPoint)
        let anchor = CGPoint(x: layer.bounds.minX + layer.anchorPoint.x * layer.bounds.width,
                             y: layer.bounds.minY + layer.anchorPoint.y * layer.bounds.height)
        let (dx, dy) = (point.x - anchor.x, point.y - anchor.y)
        var transform = CATransform3DMakeTranslation(-dx, -dy, 0)
        transform = CATransform3DConcat(transform, CATransform3DMakeScale(factor, factor, 1))
        transform = CATransform3DConcat(transform, CATransform3DMakeTranslation(dx, dy, 0))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.sublayerTransform = transform
        CATransaction.commit()
    }

    static func percentage(_ zoom: Double) -> String {
        "\(Int((zoom * 100).rounded()))%"
    }

    private static func set(_ zoom: Double) {
        UserDefaults.standard.set(zoom, forKey: key)
    }
}
