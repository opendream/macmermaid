import AppKit

// A neutral diagram mark. The app's controls follow the system accent; the
// packaged icon stays consistent instead of baking in the build machine's color.
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()

        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 1024, height: 1024).fill(using: .copy)
        let bounds = NSRect(x: 64, y: 64, width: 896, height: 896)
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 200, yRadius: 200)
        NSGraphicsContext.saveGraphicsState()
        let plateShadow = NSShadow()
        plateShadow.shadowColor = NSColor.black.withAlphaComponent(0.17)
        plateShadow.shadowBlurRadius = 20
        plateShadow.shadowOffset = NSSize(width: 0, height: -10)
        plateShadow.set()
        NSColor(calibratedWhite: 0.83, alpha: 1).setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [NSColor(calibratedWhite: 0.98, alpha: 1),
                            NSColor(calibratedWhite: 0.92, alpha: 1),
                            NSColor(calibratedWhite: 0.81, alpha: 1)])!.draw(in: shape, angle: -90)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        let rim = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 197, yRadius: 197)
        rim.lineWidth = 3
        rim.stroke()

        // Continuous branches connect all three nodes, with softened elbows.
        NSColor(calibratedWhite: 0.31, alpha: 1).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 26
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: NSPoint(x: 512, y: 650))
        path.line(to: NSPoint(x: 512, y: 492))
        path.move(to: NSPoint(x: 296, y: 370))
        path.line(to: NSPoint(x: 296, y: 464))
        path.curve(to: NSPoint(x: 324, y: 492), controlPoint1: NSPoint(x: 296, y: 483), controlPoint2: NSPoint(x: 305, y: 492))
        path.line(to: NSPoint(x: 700, y: 492))
        path.curve(to: NSPoint(x: 728, y: 464), controlPoint1: NSPoint(x: 719, y: 492), controlPoint2: NSPoint(x: 728, y: 483))
        path.line(to: NSPoint(x: 728, y: 370))
        path.stroke()
        for rect in [NSRect(x: 398, y: 626, width: 228, height: 154),
                     NSRect(x: 191, y: 240, width: 210, height: 154),
                     NSRect(x: 623, y: 240, width: 210, height: 154)] {
            let node = NSBezierPath(roundedRect: rect, xRadius: 36, yRadius: 36)
            NSGraphicsContext.saveGraphicsState()
            let nodeShadow = NSShadow()
            nodeShadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
            nodeShadow.shadowBlurRadius = 12
            nodeShadow.shadowOffset = NSSize(width: 0, height: -7)
            nodeShadow.set()
            NSColor(calibratedWhite: 0.22, alpha: 1).setFill()
            node.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGradient(starting: NSColor(calibratedWhite: 0.34, alpha: 1),
                       ending: NSColor(calibratedWhite: 0.17, alpha: 1))!.draw(in: node, angle: -90)
        }
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
    }
}
