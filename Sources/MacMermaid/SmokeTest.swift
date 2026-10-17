import AppKit
import Foundation
import WebKit
import PDFKit

/// Runs the real packaged WebKit renderer; invoked only by the explicit smoke-test flag.
@MainActor
enum SmokeTest {
    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    static func run(directory: String) async {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        var results: [String] = [] {
            didSet { try? results.joined(separator: "\n").write(to: folder.appendingPathComponent("results.txt"), atomically: true, encoding: .utf8) }
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let session = PreviewSession()
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
            window.contentView = session.webView
            window.orderBack(nil)
            defer { window.orderOut(nil) }
            try await wait { session.ready || session.error != nil }
            guard session.ready else { throw Failure(session.error ?? "Renderer failed to start") }
            results.append("PASS: bundled renderer starts offline")

            for template in DiagramTemplate.all {
                session.update(source: template.source, options: RenderOptions(), immediately: true)
                try await wait { !session.isRendering }
                guard session.error == nil, session.svg?.contains("<svg") == true else {
                    throw Failure("\(template.title): \(session.error ?? "No SVG")")
                }
                results.append("PASS: \(template.title)")
            }
            for theme in DiagramTheme.allCases {
                session.update(source: DiagramTemplate.welcome.source, options: RenderOptions(theme: theme.rawValue, dark: theme == .dark), immediately: true)
                try await wait { !session.isRendering }
                guard session.error == nil else { throw Failure("Theme \(theme.title): \(session.error!)") }
                results.append("PASS: theme \(theme.title)")
            }
            for palette in CatppuccinPalette.allCases {
                // Exercise every diagram type with both new palettes, not only flowcharts.
                for template in DiagramTemplate.all {
                    session.update(source: template.source, options: RenderOptions(theme: palette.rawValue), immediately: true)
                    try await wait { !session.isRendering }
                    guard session.error == nil else { throw Failure("\(palette.rawValue) \(template.title): \(session.error!)") }
                }
                session.update(source: DiagramTemplate.welcome.source, options: RenderOptions(theme: palette.rawValue), immediately: true)
                try await wait { !session.isRendering }
                for format in ExportFormat.allCases {
                    let data = try await session.exportData(format)
                    try data.write(to: folder.appendingPathComponent("\(palette.rawValue).\(format.rawValue)"))
                    switch format {
                    case .svg:
                        let svg = String(decoding: data, as: UTF8.self)
                        guard svg.contains("fill=\"\(palette.colors["base"]!)\""), svg.contains(palette.colors["mauve"]!) else {
                            throw Failure("\(palette.rawValue) SVG lost its palette")
                        }
                    case .png:
                        guard let bitmap = NSBitmapImageRep(data: data), matchesPixel(bitmap, palette.color("base")) else {
                            throw Failure("\(palette.rawValue) PNG background changed")
                        }
                    case .pdf:
                        guard let page = PDFDocument(data: data)?.page(at: 0) else { throw Failure("Invalid palette PDF") }
                        let image = page.thumbnail(of: NSSize(width: 800, height: 800), for: .mediaBox)
                        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                              matchesPixel(bitmap, palette.color("base")) else {
                            throw Failure("\(palette.rawValue) PDF background changed")
                        }
                        if let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                            try png.write(to: folder.appendingPathComponent("\(palette.rawValue)-pdf.png"))
                        }
                    }
                }
                results.append("PASS: \(palette.rawValue) all templates and SVG/PNG/PDF palette fidelity")
            }
            let lastSVG = session.svg
            session.update(source: "flowchart TD\nA[broken", options: RenderOptions(), immediately: true)
            try await wait { !session.isRendering }
            guard session.error != nil, session.svg == lastSVG, !session.canExport else {
                throw Failure("Invalid source must retain the last diagram and disable export")
            }
            results.append("PASS: syntax error preserves preview and disables export")
            session.update(source: "flowchart LR\nA[สวัสดี 🌿] --> B[Hello]", options: RenderOptions(), immediately: true)
            session.update(source: DiagramTemplate.welcome.source, options: RenderOptions(), immediately: true)
            try await wait { !session.isRendering }
            try session.svg?.write(to: folder.appendingPathComponent("recovery.svg"), atomically: true, encoding: .utf8)
            guard session.canExport, session.svg?.contains("flowchart-idea") == true else {
                throw Failure("Recovery or latest render failed: export=\(session.canExport), error=\(session.error ?? "none")")
            }
            results.append("PASS: latest edit wins and recovers after error")

            for format in ExportFormat.allCases {
                let data = try await session.exportData(format)
                guard data.count > 100 else { throw Failure("Empty \(format.title) export") }
                if format == .png && !data.starts(with: [137, 80, 78, 71]) { throw Failure("Invalid PNG signature") }
                if format == .pdf && !data.starts(with: Data("%PDF".utf8)) { throw Failure("Invalid PDF signature") }
                try data.write(to: folder.appendingPathComponent("diagram.\(format.rawValue)"))
                results.append("PASS: \(format.title) export (\(data.count) bytes)")
            }
            let snapshot = try await session.webView.takeSnapshot(configuration: nil)
            if let tiff = snapshot.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                try png.write(to: folder.appendingPathComponent("preview.png"))
            }
            session.update(source: "", options: RenderOptions(), immediately: true)
            try await wait { !session.isRendering }
            guard session.svg == nil && session.error == nil && !session.canExport else { throw Failure("Empty source did not clear the preview") }
            results.append("PASS: empty source clears preview")
            try await checkNativeDocument(in: folder)
            results.append("PASS: native document open, edit, autosave, undo, and save")
            results.append("PASS: live native editor/canvas appearance changes, manual overrides, persisted legacy choice, and layout snapshots")
            results.append("SUCCESS")
        } catch {
            results.append("FAIL: \(error)")
        }
        try? results.joined(separator: "\n").write(to: folder.appendingPathComponent("results.txt"), atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }

    private static func checkNativeDocument(in folder: URL) async throws {
        // DocumentGroup may present its startup picker while the renderer tests run.
        // Dismiss only this test instance's picker before exercising window controls.
        for panel in NSApp.windows.compactMap({ $0 as? NSOpenPanel }) { panel.cancel(nil) }
        let original = DiagramTemplate.welcome.source
        let url = folder.appendingPathComponent("document.mmd")
        try original.write(to: url, atomically: true, encoding: .utf8)
        let controller = NSDocumentController.shared
        let document = try controller.makeDocument(withContentsOf: url, ofType: "app.macmermaid.diagram")
        controller.addDocument(document)
        document.makeWindowControllers()
        document.showWindows()
        defer { document.close() }
        guard type(of: document).autosavesInPlace else { throw Failure("Native document does not autosave in place") }
        try await wait("native document window") { document.windowControllers.first?.window?.contentView != nil }
        guard let content = document.windowControllers.first?.window?.contentView else { throw Failure("No document view") }
        func findEditor(_ view: NSView) -> SourceTextView? {
            if let editor = view as? SourceTextView { return editor }
            return view.subviews.lazy.compactMap { findEditor($0) }.first
        }
        try await wait("native document editor") { findEditor(content) != nil }
        guard let editor = findEditor(content), editor.string == original else { throw Failure("Native open changed the source") }
        editor.window?.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: (original as NSString).length, length: 0))
        let addition = "\n%% Autosave round trip · สวัสดี 🌿\n"
        editor.insertText(addition, replacementRange: editor.selectedRange())
        try await wait("native document edit") { document.isDocumentEdited }
        try await document.autosave(withImplicitCancellability: false)
        guard try String(contentsOf: url, encoding: .utf8) == original + addition else { throw Failure("Autosave lost editor changes") }
        editor.undoManager?.undo()
        try await wait("native document undo") { editor.string == original }
        try await document.save(to: url, ofType: "app.macmermaid.diagram", for: .saveOperation)
        guard try String(contentsOf: url, encoding: .utf8) == original else { throw Failure("Undo was not saved correctly") }
        guard let window = editor.window else { throw Failure("No native document window") }
        try await checkWorkspaceThemes(window: window, editor: editor, folder: folder)
    }

    private static func matches(_ actual: NSColor, _ expected: NSColor) -> Bool {
        guard let a = actual.usingColorSpace(.sRGB), let b = expected.usingColorSpace(.sRGB) else { return false }
        return abs(a.redComponent - b.redComponent) < 0.025 && abs(a.greenComponent - b.greenComponent) < 0.025 && abs(a.blueComponent - b.blueComponent) < 0.025
    }

    private static func matchesPixel(_ bitmap: NSBitmapImageRep, _ expected: NSColor) -> Bool {
        // colorAt() labels decoded PNG components as calibrated RGB on macOS 27;
        // compare actual sRGB pixel samples to avoid an extra color conversion.
        guard bitmap.bitsPerSample == 8, bitmap.samplesPerPixel >= 3,
              let color = expected.usingColorSpace(.sRGB) else { return false }
        var samples = [Int](repeating: 0, count: bitmap.samplesPerPixel)
        bitmap.getPixel(&samples, atX: 4, y: 4)
        return zip(samples.prefix(3), [color.redComponent, color.greenComponent, color.blueComponent])
            .allSatisfy { abs(Double($0.0) / 255 - $0.1) < 0.025 }
    }

    private static func checkWorkspaceThemes(window: NSWindow, editor: SourceTextView, folder: URL) async throws {
        let defaults = UserDefaults.standard
        let savedTheme = defaults.object(forKey: "diagramTheme")
        let savedAppearance = defaults.object(forKey: "appearance")
        let savedAppAppearance = NSApp.appearance
        defer {
            defaults.set(savedTheme, forKey: "diagramTheme")
            defaults.set(savedAppearance, forKey: "appearance")
            NSApp.appearance = savedAppAppearance
        }
        func findWebView(_ view: NSView) -> WKWebView? {
            if let web = view as? WKWebView { return web }
            return view.subviews.lazy.compactMap { findWebView($0) }.first
        }
        guard let content = window.contentView, let web = findWebView(content) else { throw Failure("No native preview") }
        defaults.set("system", forKey: "appearance")
        defaults.removeObject(forKey: "diagramTheme")
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        func check(_ palette: CatppuccinPalette) async throws {
            do {
                try await wait("editor palette \(palette.rawValue)") { matches(editor.backgroundColor, palette.color("base")) }
            } catch {
                throw Failure("\(error): actual \(editor.backgroundColor), effective \(window.effectiveAppearance.name), preference \(defaults.string(forKey: "diagramTheme") ?? "unset")")
            }
            let deadline = Date().addingTimeInterval(30)
            while true {
                let value = try await web.evaluateJavaScript("document.documentElement.style.getPropertyValue('--canvas') + '|' + (document.querySelector('#stage svg')?.textContent || '')") as? String ?? ""
                if value.hasPrefix(palette.colors["base"]! + "|"), value.contains(palette.colors["mauve"]!) { break }
                guard Date() < deadline else { throw Failure("Editor/canvas theme mismatch for \(palette.rawValue)") }
                try await Task.sleep(for: .milliseconds(80))
            }
            guard let storage = editor.textStorage else { throw Failure("No editor storage") }
            for token in MermaidSyntax.tokens(in: editor.string) where token.kind == .keyword || token.kind == .arrow {
                guard let color = storage.attribute(.foregroundColor, at: token.range.location, effectiveRange: nil) as? NSColor,
                      matches(color, palette.syntaxColor(token.kind)) else { throw Failure("Syntax palette did not update") }
            }
        }

        // The same effective-appearance changes delivered by macOS, without changing system settings.
        NSApp.appearance = NSAppearance(named: .aqua)
        try await check(.latte)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        try await check(.mocha)
        defaults.set("latte", forKey: "diagramTheme")
        try await check(.latte)
        NSApp.appearance = NSAppearance(named: .aqua)
        try await check(.latte)
        defaults.set("mocha", forKey: "diagramTheme")
        try await check(.mocha)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        try await check(.mocha)

        defaults.set("system", forKey: "diagramTheme")
        // SwiftUI's virtual children and toolbar viewers expose the AppKit attribute API.
        func accessible(_ object: Any, label: String) -> NSObject? {
            guard let element = object as? NSObject else { return nil }
            let description = element.accessibilityAttributeValue(.description) as? String
            let title = element.accessibilityAttributeValue(.title) as? String
            if description == label || title == label { return element }
            return ((element.accessibilityAttributeValue(.children) as? [Any]) ?? []).lazy.compactMap { accessible($0, label: label) }.first
        }
        func describe(_ object: Any, depth: Int = 0) -> [String] {
            guard depth < 15, let element = object as? any NSAccessibilityProtocol else { return [] }
            let entry = "\(String(repeating: " ", count: depth))\(type(of: element)) role=\(element.accessibilityRole()?.rawValue ?? "nil") label=\(element.accessibilityLabel() ?? "nil") title=\(element.accessibilityTitle() ?? "nil")"
            return [entry] + (element.accessibilityChildren() ?? []).flatMap { describe($0, depth: depth + 1) }
        }
        try describe(window).joined(separator: "\n").write(to: folder.appendingPathComponent("workspace-accessibility.txt"), atomically: true, encoding: .utf8)
        try await wait("appearance toolbar button") { accessible(window, label: "Appearance") != nil }
        guard let appearanceButton = accessible(window, label: "Appearance") else { throw Failure("Appearance toolbar button unavailable") }
        appearanceButton.accessibilityPerformAction(.press)
        func inspectorScrollView(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView, abs(scroll.frame.width - 238) < 1 { return scroll }
            return view.subviews.lazy.compactMap { inspectorScrollView($0) }.first
        }
        try await wait("visible theme inspector") { inspectorScrollView(content) != nil }
        for palette in CatppuccinPalette.allCases {
            NSApp.appearance = NSAppearance(named: palette.isDark ? .darkAqua : .aqua)
            try await check(palette)
            for (label, size) in [("normal", NSSize(width: 1260, height: 820)), ("minimum", NSSize(width: 960, height: 540))] {
                window.setContentSize(size)
                try await Task.sleep(for: .milliseconds(300))
                content.layoutSubtreeIfNeeded()
                _ = try await web.takeSnapshot(configuration: nil)
                guard let frame = content.superview, let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else {
                    throw Failure("Cannot snapshot native workspace")
                }
                frame.cacheDisplay(in: frame.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw Failure("Cannot encode workspace snapshot") }
                try png.write(to: folder.appendingPathComponent("workspace-\(palette.rawValue)-\(label).png"))
            }
        }
        defaults.set("ocean", forKey: "diagramTheme")
        NSApp.appearance = NSAppearance(named: .aqua)
        try await Task.sleep(for: .milliseconds(400))
        guard defaults.string(forKey: "diagramTheme") == "ocean" else { throw Failure("Explicit legacy selection overwritten") }
        defaults.synchronize()
        guard let domain = Bundle.main.bundleIdentifier, UserDefaults.standard.persistentDomain(forName: domain)?["diagramTheme"] as? String == "ocean" else {
            throw Failure("Theme choice was not persisted")
        }
    }

    private static func wait(_ description: String = "WebKit", _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(30)
        while !condition() {
            guard Date() < deadline else { throw Failure("Timed out waiting for \(description)") }
            try await Task.sleep(for: .milliseconds(80))
        }
    }
}
