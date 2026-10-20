import AppKit

// Renders the "H" app icon in layers so shadows can be drawn with Core Graphics
// (AppKit's SVG renderer ignores SVG filters).
let header = ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">"##
let background = header + ##"""
<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E3896A"/><stop offset="1" stop-color="#C4613F"/></linearGradient></defs>
<rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/>
<rect x="101.5" y="101.5" width="821" height="821" rx="183.5" fill="none" stroke="#FFFFFF" stroke-opacity="0.18" stroke-width="3"/>
</svg>
"""##
let card = header + ##"<rect x="212" y="262" width="600" height="500" rx="56" fill="#F5F1E8"/></svg>"##
let details = header + ##"""
<rect x="507" y="262" width="10" height="500" fill="#D97757"/>
<g fill="none" stroke="#C4613F" stroke-width="56" stroke-linecap="round" stroke-linejoin="round">
<path d="M286 628 V396 L360 482 L434 396 V628"/>
<path d="M662 396 V612 M586 538 L662 616 L738 538"/>
</g></svg>
"""##

func image(_ svg: String) -> NSImage {
    guard let image = NSImage(data: Data(svg.utf8)) else { fatalError("SVG not supported") }
    return image
}

let layers: [(NSImage, blur: CGFloat, offset: CGFloat, opacity: CGFloat, color: NSColor)] = [
    (image(background), 24, 10, 0.28, .black),
    (image(card), 16, 6, 0.25, NSColor(red: 0.35, green: 0.14, blue: 0.08, alpha: 1)),
    (image(details), 0, 0, 0, .clear),
]

let outDir = CommandLine.arguments[1]
for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / 1024
    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    for layer in layers {
        NSGraphicsContext.saveGraphicsState()
        if layer.opacity > 0 {
            let shadow = NSShadow()
            shadow.shadowBlurRadius = layer.blur * scale
            shadow.shadowOffset = NSSize(width: 0, height: -layer.offset * scale)
            shadow.shadowColor = layer.color.withAlphaComponent(layer.opacity)
            shadow.set()
        }
        layer.0.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/icon_\(pixels).png"))
}
print("done")
