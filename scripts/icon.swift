import AppKit

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
        let bounds = NSRect(x: 60, y: 60, width: 904, height: 904)
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 205, yRadius: 205)
        NSGradient(starting: NSColor(calibratedRed: 0.27, green: 0.72, blue: 0.62, alpha: 1), ending: NSColor(calibratedRed: 0.08, green: 0.33, blue: 0.35, alpha: 1))!.draw(in: shape, angle: -65)
        NSColor.white.withAlphaComponent(0.7).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 28
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: 512, y: 680))
        path.line(to: NSPoint(x: 512, y: 525))
        path.move(to: NSPoint(x: 300, y: 365))
        path.line(to: NSPoint(x: 300, y: 480))
        path.line(to: NSPoint(x: 724, y: 480))
        path.line(to: NSPoint(x: 724, y: 365))
        path.stroke()
        for rect in [NSRect(x: 392, y: 630, width: 240, height: 150), NSRect(x: 198, y: 245, width: 204, height: 148), NSRect(x: 622, y: 245, width: 204, height: 148)] {
            let node = NSBezierPath(roundedRect: rect, xRadius: 38, yRadius: 38)
            NSColor.white.withAlphaComponent(0.9).setFill(); node.fill()
            NSColor.white.setStroke(); node.lineWidth = 4; node.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
    }
}
