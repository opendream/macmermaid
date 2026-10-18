import AppKit
import Foundation
import WebKit
import PDFKit

/// Runs the real packaged WebKit renderer; invoked only by the explicit smoke-test flag.
@MainActor
enum SmokeTest {
    private(set) static var isRunning = false
    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    static func run(directory: String) async {
        isRunning = true
        defer { isRunning = false }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        var results: [String] = [] {
            didSet { try? results.joined(separator: "\n").write(to: folder.appendingPathComponent("results.txt"), atomically: true, encoding: .utf8) }
        }
        do {
            NSWindow.allowsAutomaticWindowTabbing = false
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let session = PreviewSession()
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
            window.contentView = session.webView
            window.orderBack(nil)
            defer { window.orderOut(nil) }
            try await wait { session.ready || session.error != nil }
            guard session.ready else { throw Failure(session.error ?? "Renderer failed to start") }
            results.append("Renderer: Mermaid \(RendererMetadata.version), SHA-256 \(RendererMetadata.checksum)")
            results.append("System: \(ProcessInfo.processInfo.operatingSystemVersionString)")
            try await checkIsolationAndPortability(session: session, folder: folder)
            results.append("PASS: local resources, CSP-blocked network request, and six portable palettes in standalone Mermaid")
            try await checkConfiguration(session: session)
            results.append("PASS: native defaults, layouts, looks, curve geometry, scoped settings, malformed YAML, and recovery")
            try await checkViewport(session: session, window: window)
            results.append("PASS: very wide diagram fits below 5%, zoom stays continuous, and resizing refits")

            for template in DiagramTemplate.all {
                for theme in DiagramTheme.allCases {
                    let source = try await themedSource(template.source, theme: theme.rawValue, web: session.webView)
                    session.update(source: source, options: RenderOptions(), immediately: true)
                    try await wait { !session.isRendering }
                    guard session.error == nil, session.svg?.contains("<svg") == true else {
                        throw Failure("\(template.title) / \(theme.title): \(session.error ?? "No SVG")")
                    }
                    if session.appearance?.theme != theme.rawValue {
                        let diagnostics = try await session.webView.evaluateJavaScript("JSON.stringify(window.macmermaid.diagnostics())") as? String ?? "none"
                        try diagnostics.write(to: folder.appendingPathComponent("appearance-failure.json"), atomically: true, encoding: .utf8)
                        throw Failure("Inspector selection mismatch: \(theme.rawValue) became \(session.appearance?.theme ?? "nil")")
                    }
                    if template.id == "gantt" {
                        let readable = try await session.webView.evaluateJavaScript("""
                            (() => {
                              const ticks = [...document.querySelectorAll('#stage .tick text')]
                                .map(n => n.getBoundingClientRect()).sort((a,b) => a.left-b.left);
                              return ticks.length > 1 && ticks.every((r,i) => !i || r.left > ticks[i-1].right);
                            })()
                            """) as? Bool
                        guard readable == true else { throw Failure("Project-plan date labels overlap") }
                    }
                    if template.id == "mindmap", let palette = DiagramPalette(rawValue: theme.rawValue) {
                        guard session.svg?.contains("stroke:\(palette.colors["mauve"]!)") == true else {
                            throw Failure("Mind-map branches lost the explicit palette scale")
                        }
                    }
                    if theme == .reduxColor || theme == .mocha {
                        for format in ExportFormat.allCases {
                            let data = try await session.exportData(format)
                            try data.write(to: folder.appendingPathComponent("\(template.id)-\(theme.rawValue).\(format.rawValue)"))
                            guard data.count > 100 else { throw Failure("Empty template export") }
                            if format == .png && NSBitmapImageRep(data: data) == nil { throw Failure("Invalid template PNG") }
                            if format == .pdf {
                                guard let pdf = PDFDocument(data: data), pdf.pageCount == 1, let page = pdf.page(at: 0),
                                      let tiff = page.thumbnail(of: NSSize(width: 1200, height: 1200), for: .mediaBox).tiffRepresentation,
                                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                                    throw Failure("Invalid template PDF")
                                }
                                try png.write(to: folder.appendingPathComponent("\(template.id)-\(theme.rawValue)-pdf.png"))
                            }
                        }
                    }
                }
                results.append("PASS: \(template.title), every theme and light/dark SVG/PNG/PDF exports")
            }
            for palette in DiagramPalette.allCases {
                let source = try await themedSource(DiagramTemplate.welcome.source, theme: palette.rawValue, web: session.webView)
                session.update(source: source, options: RenderOptions(), immediately: true)
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
            results.append("PASS: native document open, edit, autosave, appearance undo/redo, save/reopen, and independent documents")
            results.append("PASS: document-owned appearance, Settings appearance overrides, and layout snapshots")
            results.append("SUCCESS")
        } catch {
            results.append("FAIL: \(error)")
        }
        try? results.joined(separator: "\n").write(to: folder.appendingPathComponent("results.txt"), atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }

    private static func checkViewport(session: PreviewSession, window: NSWindow) async throws {
        let source = "flowchart LR\n" + (0..<100).map { "step\($0)[Step \($0)]" }.joined(separator: " --> ")
        window.setContentSize(NSSize(width: 400, height: 540))
        defer { window.setContentSize(NSSize(width: 1000, height: 760)) }
        session.update(source: source, options: RenderOptions(), immediately: true)
        try await wait { !session.isRendering }
        guard session.canExport else { throw Failure(session.error ?? "Wide diagram did not render") }
        let result = try await session.webView.callAsyncJavaScript("""
            // Reading layout works even when this test window is occluded;
            // requestAnimationFrame can stay suspended in background WebKit.
            window.macmermaid.fit();
            const viewport = document.getElementById('viewport');
            const stage = document.getElementById('stage');
            const scale = () => new DOMMatrix(getComputedStyle(stage).transform).a;
            const contained = () => {
              const v = viewport.getBoundingClientRect(), s = stage.getBoundingClientRect();
              return s.left >= v.left - 0.1 && s.right <= v.right + 0.1 &&
                s.top >= v.top - 0.1 && s.bottom <= v.bottom + 0.1;
            };
            const fitted = scale();
            if (!(fitted > 0 && fitted < 0.05 && contained())) return false;
            window.macmermaid.zoom(1.2);
            if (Math.abs(scale() / fitted - 1.2) > 0.0001) return false;
            window.macmermaid.zoom(1 / 1.2);
            return contained() && document.querySelectorAll('#stage .node').length === 100;
            """, arguments: [:], in: nil, contentWorld: .page) as? Bool
        guard result == true else { throw Failure("Wide-diagram Fit or zoom clips the diagram") }
        window.setContentSize(NSSize(width: 1000, height: 760))
        let resized = try await session.webView.callAsyncJavaScript("""
            window.macmermaid.fit();
            const v = document.getElementById('viewport').getBoundingClientRect();
            const s = document.getElementById('stage').getBoundingClientRect();
            return s.left >= v.left - 0.1 && s.right <= v.right + 0.1 &&
              s.top >= v.top - 0.1 && s.bottom <= v.bottom + 0.1;
            """, arguments: [:], in: nil, contentWorld: .page) as? Bool
        guard resized == true else { throw Failure("Resized viewport clips a fitted diagram") }
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
        try await checkNativeAppearance(document: document, editor: editor, url: url, folder: folder)
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
        let savedAppearance = defaults.object(forKey: "appearance")
        let savedAppAppearance = NSApp.appearance
        defer {
            defaults.set(savedAppearance, forKey: "appearance")
            NSApp.appearance = savedAppAppearance
        }
        func findWebView(_ view: NSView) -> WKWebView? {
            if let web = view as? WKWebView { return web }
            return view.subviews.lazy.compactMap { findWebView($0) }.first
        }
        guard let content = window.contentView, let web = findWebView(content) else { throw Failure("No native preview") }
        defer {
            func frames(_ view: NSView, depth: Int = 0) -> [String] {
                ["\(String(repeating: " ", count: depth))\(type(of: view)) \(view.frame) hidden=\(view.isHidden)"] + view.subviews.flatMap { frames($0, depth: depth + 1) }
            }
            let state = "key=\(window.isKeyWindow) main=\(window.isMainWindow) active=\(NSApp.isActive) toolbar=\(window.toolbar?.isVisible.description ?? "nil") items=\(window.toolbar?.items.map(\.label) ?? [])\n"
            try? (state + frames(content).joined(separator: "\n")).write(to: folder.appendingPathComponent("workspace-frames.txt"), atomically: true, encoding: .utf8)
            if let frame = content.superview, let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) {
                frame.cacheDisplay(in: frame.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("workspace-final.png"))
            }
        }
        defaults.set("system", forKey: "appearance")
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.toolbar?.isVisible = true

        func checkEditor(dark: Bool) async throws {
            let background = dark ? NSColor(calibratedRed: 0.105, green: 0.135, blue: 0.15, alpha: 1)
                                  : NSColor(calibratedRed: 0.985, green: 0.987, blue: 0.985, alpha: 1)
            try await wait("standard editor \(dark ? "dark" : "light") appearance") { matches(editor.backgroundColor, background) }
            guard let storage = editor.textStorage else { throw Failure("No editor storage") }
            for token in MermaidSyntax.tokens(in: editor.string) where token.kind == .keyword || token.kind == .arrow {
                let expected: NSColor = token.kind == .keyword
                    ? (dark ? .systemTeal : NSColor(calibratedRed: 0.12, green: 0.43, blue: 0.43, alpha: 1))
                    : (dark ? .systemPurple : NSColor(calibratedRed: 0.52, green: 0.39, blue: 0.68, alpha: 1))
                guard let actual = storage.attribute(.foregroundColor, at: token.range.location, effectiveRange: nil) as? NSColor,
                      matches(actual, expected) else { throw Failure("Diagram theme changed standard editor syntax colors") }
            }
        }

        func checkCanvas(_ palette: DiagramPalette) async throws {
            let deadline = Date().addingTimeInterval(30)
            while true {
                let value = try await web.evaluateJavaScript("document.documentElement.style.getPropertyValue('--canvas') + '|' + (document.querySelector('#stage svg')?.textContent || '')") as? String ?? ""
                if value.hasPrefix(palette.colors["base"]! + "|"), value.contains(palette.colors["mauve"]!) { break }
                guard Date() < deadline else { throw Failure("Canvas palette did not update for \(palette.rawValue)") }
                try await Task.sleep(for: .milliseconds(80))
            }
        }

        // System follows effective macOS appearance; explicit Settings overrides win.
        // Change only this test app's appearance, never the user's macOS settings.
        NSApp.appearance = NSAppearance(named: .aqua)
        try await checkEditor(dark: false)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        try await checkEditor(dark: true)
        defaults.set("light", forKey: "appearance")
        try await checkEditor(dark: false)
        NSApp.appearance = NSAppearance(named: .aqua)
        defaults.set("dark", forKey: "appearance")
        try await checkEditor(dark: true)
        window.setContentSize(NSSize(width: 1260, height: 820))
        // SwiftUI installs the toolbar asynchronously; setting visibility before
        // it exists leaves restored hidden-toolbar state in effect on some runs.
        try await wait("native document toolbar") { window.toolbar != nil }
        window.toolbar?.isVisible = true
        content.layoutSubtreeIfNeeded()
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(editor)
        // These integration checks address the document/editor directly. A host
        // app may retain foreground focus when the suite is launched from a CLI;
        // that must not block save/undo/render checks. Keyboard and accessibility
        // interaction still require a separate visible UI check, not this suite.

        // WorkspaceView seeds inspector visibility for this explicit smoke run.
        // SwiftUI's AX tree is lazy until an external accessibility client connects,
        // so in-process AX presses cannot reliably open it. Visible toolbar/menu
        // interactions are checked separately in the native review app.
        func inspectorScrollView(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView, abs(scroll.frame.width - 238) < 1 { return scroll }
            return view.subviews.lazy.compactMap { inspectorScrollView($0) }.first
        }
        try await wait("visible theme inspector") { inspectorScrollView(content) != nil }
        try await Task.sleep(for: .milliseconds(400))
        if let frame = content.superview, let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) {
            frame.cacheDisplay(in: frame.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("inspector.png"))
        }
        // Exercise the same bridge and native text edit used by the inspector.
        // External UI checks separately exercise the visible controls.
        for dark in [false, true] {
            defaults.set(dark ? "dark" : "light", forKey: "appearance")
            // Deliberately oppose Settings to the simulated system appearance.
            NSApp.appearance = NSAppearance(named: dark ? .aqua : .darkAqua)
            try await checkEditor(dark: dark)
            for theme in ["default"] + DiagramPalette.allCases.map(\.rawValue) {
                let updated = try await themedSource(DiagramTemplate.welcome.source, theme: theme, web: web)
                let sourceEditor = SourceEditorController()
                sourceEditor.editor = editor
                try sourceEditor.replace(updated, expected: editor.string, actionName: "Change Diagram Theme")
                if let palette = DiagramPalette(rawValue: theme) { try await checkCanvas(palette) }
                else { try await waitAppearance(web, field: "theme", value: "default") }
                try await checkEditor(dark: dark)
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
                    try png.write(to: folder.appendingPathComponent("workspace-\(dark ? "dark" : "light")-\(theme)-\(label).png"))
                }
                window.setContentSize(NSSize(width: 1260, height: 820))
            }
        }

    }

    private static func checkIsolationAndPortability(session: PreviewSession, folder: URL) async throws {
        let isolated = try await session.webView.callAsyncJavaScript("""
            const local = [...document.scripts].every(s => s.src.startsWith('file:'));
            const blocked = new Promise(resolve => {
              const timer = setTimeout(() => resolve(false), 3000);
              document.addEventListener('securitypolicyviolation', event => {
                if (event.effectiveDirective === 'connect-src') { clearTimeout(timer); resolve(true); }
              }, {once: true});
            });
            try { await fetch('https://macmermaid-offline-test.invalid/probe'); } catch (_) {}
            return local && await blocked;
            """, arguments: [:], in: nil, contentWorld: .page) as? Bool
        guard isolated == true else { throw Failure("Local resource or offline CSP check failed") }

        // A separate page has only the upstream renderer: no app bridge, palette table,
        // YAML editor, or MacMermaid initialization defaults can affect this result.
        let directory = folder.appendingPathComponent("standalone", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let bundle = Bundle.module.url(forResource: "mermaid.min", withExtension: "js", subdirectory: "Web") else {
            throw Failure("Missing Mermaid bundle")
        }
        try Data(contentsOf: bundle).write(to: directory.appendingPathComponent("mermaid.min.js"))
        let page = directory.appendingPathComponent("index.html")
        try """
        <!doctype html><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; img-src data:; connect-src 'none'">
        <script src="mermaid.min.js"></script><body></body>
        """.write(to: page, atomically: true, encoding: .utf8)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 760), configuration: configuration)
        let window = NSWindow(contentRect: web.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = web
        window.orderBack(nil)
        defer { window.orderOut(nil) }
        web.loadFileURL(page, allowingReadAccessTo: directory)
        let deadline = Date().addingTimeInterval(30)
        while (try? await web.evaluateJavaScript("typeof mermaid === 'object'")) as? Bool != true {
            guard Date() < deadline else { throw Failure("Standalone Mermaid did not load") }
            try await Task.sleep(for: .milliseconds(80))
        }
        for theme in ["studio", "ocean"] + DiagramPalette.allCases.map(\.rawValue) {
            let source = try await themedSource(DiagramTemplate.welcome.source, theme: theme, web: session.webView)
            let svg = try await web.callAsyncJavaScript("""
                if (window.macmermaid || window.MacMermaidAppearance) throw Error('Unexpected app helper');
                mermaid.initialize({startOnLoad: false, securityLevel: 'strict'});
                const parsed = await mermaid.parse(source);
                if (parsed.config.theme !== 'base' || !parsed.config.themeVariables.primaryColor) throw Error('Nonportable palette');
                return (await mermaid.render('portable_' + name.replaceAll('-', '_'), source)).svg;
                """, arguments: ["source": source, "name": theme], in: nil, contentWorld: .page) as? String
            guard let svg, svg.contains("<svg"), svg.contains("Write it down") else { throw Failure("Standalone palette failed: \(theme)") }
            if let palette = DiagramPalette(rawValue: theme), !svg.contains(palette.colors["mauve"]!) { throw Failure("Standalone palette lost colors") }
            try source.write(to: directory.appendingPathComponent("\(theme).mmd"), atomically: true, encoding: .utf8)
            try svg.write(to: directory.appendingPathComponent("\(theme).svg"), atomically: true, encoding: .utf8)
        }
    }

    private static func checkConfiguration(session: PreviewSession) async throws {
        func render(_ source: String) async throws {
            session.update(source: source, options: RenderOptions(), immediately: true)
            try await wait { !session.isRendering }
            if let error = session.error { throw Failure("\(error)\nSource: \(source.prefix(300))") }
        }
        let original = DiagramTemplate.welcome.source
        try await render(original)
        guard session.appearance?.theme == "default", session.appearance?.effectiveTheme == "redux-color",
              session.appearance?.effectiveLook == "neo", session.appearance?.effectiveLayout == "elk",
              session.appearance?.supportsCurve == false else { throw Failure("Unexpected native defaults") }
        var source = try await session.sourceByChangingAppearance("layout", to: "dagre", source: original)
        try await render(source)
        guard session.appearance?.effectiveLayout == "dagre", session.appearance?.supportsCurve == true else { throw Failure("Dagre controls did not become available") }
        var paths = Set<String>()
        for curve in ["basis", "linear", "stepAfter"] {
            source = try await session.sourceByChangingAppearance("curve", to: curve, source: source)
            try await render(source)
            let path = try await session.webView.evaluateJavaScript("JSON.stringify([...document.querySelectorAll('#stage .edgePaths path')].map(p=>p.getAttribute('d')))") as? String ?? ""
            guard path.count > 5 else { throw Failure("No connection paths") }
            paths.insert(path)
        }
        guard paths.count == 3 else { throw Failure("Connection styles do not produce distinct paths") }
        for template in DiagramTemplate.all {
            try await render(template.source)
            let looks = session.appearance?.supportedLooks ?? []
            let hasLayout = session.appearance?.supportsLayout == true
            for look in looks {
                let changed = try await session.sourceByChangingAppearance("look", to: look, source: template.source)
                try await render(changed)
                guard session.appearance?.effectiveLook == look else { throw Failure("Look override was ineffective") }
                try await render(template.source)
            }
            if hasLayout {
                for layout in ["dagre", "elk"] {
                    let changed = try await session.sourceByChangingAppearance("layout", to: layout, source: template.source)
                    try await render(changed)
                    guard session.appearance?.effectiveLayout == layout else { throw Failure("Layout override was ineffective") }
                    try await render(template.source)
                }
            }
            if template.id.hasPrefix("swimlane") {
                guard !hasLayout, session.appearance?.effectiveLayout == "swimlane" else { throw Failure("Swimlane lost its dedicated layout") }
            }
        }
        let scoped = "---\nconfig:\n  layout: elk\n  flowchart:\n    layout: dagre\n    look: classic\n---\n" + original
        try await render(scoped)
        guard session.appearance?.effectiveLayout == "dagre", session.appearance?.effectiveLook == "classic" else { throw Failure("Scoped config precedence is wrong") }
        source = try await session.sourceByChangingAppearance("layout", to: "elk", source: scoped)
        try await render(source)
        guard session.appearance?.effectiveLayout == "elk", session.appearance?.supportsCurve == false else { throw Failure("Scoped layout change did not take effect") }
        source = try await session.sourceByChangingAppearance("layout", to: "default", source: source)
        try await render(source)
        guard session.appearance?.layout == "default" else { throw Failure("Default left an applicable override") }
        try await render("---\nconfig:\n  theme: dark\n  themeVariables: {fontSize: 18px}\n---\n" + original)
        guard session.appearance?.theme == "custom", session.appearance?.isDark == true else {
            throw Failure("Custom typography lost the effective dark appearance")
        }
        let lastSVG = session.svg
        session.update(source: "---\nconfig: [broken\n---\n" + original, options: RenderOptions(), immediately: true)
        try await wait { !session.isRendering }
        guard session.error != nil, !session.canExport, session.svg == lastSVG else { throw Failure("Malformed YAML did not preserve the last preview") }
        try await render(original)
    }

    private static func nativeWebView(_ view: NSView) -> WKWebView? {
        if let web = view as? WKWebView { return web }
        return view.subviews.lazy.compactMap { nativeWebView($0) }.first
    }
    private static func nativeEditor(_ view: NSView) -> SourceTextView? {
        if let editor = view as? SourceTextView { return editor }
        return view.subviews.lazy.compactMap { nativeEditor($0) }.first
    }
    private static func waitAppearance(_ web: WKWebView, field: String, value: String) async throws {
        let deadline = Date().addingTimeInterval(30)
        while true {
            let actual = try? await web.callAsyncJavaScript("return window.macmermaid?.diagnostics()?.appearance[field]", arguments: ["field": field], in: nil, contentWorld: .page)
            if actual as? String == value { return }
            guard Date() < deadline else { throw Failure("Appearance did not become \(field)=\(value)") }
            try await Task.sleep(for: .milliseconds(80))
        }
    }
    private static func checkNativeAppearance(document: NSDocument, editor: SourceTextView, url: URL, folder: URL) async throws {
        guard let content = editor.window?.contentView, let web = nativeWebView(content) else { throw Failure("Native preview missing") }
        let sourceEditor = SourceEditorController()
        sourceEditor.editor = editor
        let original = DiagramTemplate.welcome.source
        try sourceEditor.replace(original, expected: editor.string, actionName: "Reset Test Document")
        try await waitAppearance(web, field: "theme", value: "default")
        let changed = try await themedSource(original, theme: "latte", web: web)
        try sourceEditor.replace(changed, expected: original, actionName: "Change Diagram Theme")
        try await waitAppearance(web, field: "theme", value: "latte")
        editor.undoManager?.undo()
        try await wait("appearance undo source") { editor.string == original }
        try await waitAppearance(web, field: "theme", value: "default")
        editor.undoManager?.redo()
        try await wait("appearance redo source") { editor.string == changed }
        try await waitAppearance(web, field: "theme", value: "latte")
        try await document.save(to: url, ofType: "app.macmermaid.diagram", for: .saveOperation)
        guard try String(contentsOf: url, encoding: .utf8) == changed else { throw Failure("Appearance did not save") }

        // Manual source changes must feed the same inspector model without a rewrite.
        let manual = changed.replacingOccurrences(of: "config:\n", with: "config:\n  flowchart:\n    layout: dagre\n    look: classic\n")
        try sourceEditor.replace(manual, expected: changed, actionName: "Edit Source")
        try await waitAppearance(web, field: "layout", value: "dagre")
        try await waitAppearance(web, field: "look", value: "classic")
        guard editor.string == manual else { throw Failure("Manual frontmatter was rewritten") }
        try await document.save(to: url, ofType: "app.macmermaid.diagram", for: .saveOperation)

        let secondURL = folder.appendingPathComponent("independent.mmd")
        let secondSource = "---\nconfig:\n  theme: forest\n---\n" + original
        try secondSource.write(to: secondURL, atomically: true, encoding: .utf8)
        let controller = NSDocumentController.shared
        let second = try controller.makeDocument(withContentsOf: secondURL, ofType: "app.macmermaid.diagram")
        controller.addDocument(second); second.makeWindowControllers(); second.showWindows()
        defer { second.close() }
        try await wait("second document") { second.windowControllers.first?.window?.contentView.flatMap { nativeWebView($0) } != nil }
        let secondContent = second.windowControllers.first!.window!.contentView!
        let secondWeb = nativeWebView(secondContent)!
        try await waitAppearance(secondWeb, field: "theme", value: "forest")
        try await waitAppearance(web, field: "theme", value: "latte")
        guard editor.string == manual, nativeEditor(secondContent)?.string == secondSource else { throw Failure("Documents shared appearance state") }

        document.close()
        let reopened = try controller.makeDocument(withContentsOf: url, ofType: "app.macmermaid.diagram")
        controller.addDocument(reopened); reopened.makeWindowControllers(); reopened.showWindows()
        defer { reopened.close() }
        try await wait("reopened document") { reopened.windowControllers.first?.window?.contentView.flatMap { nativeWebView($0) } != nil }
        let reopenedContent = reopened.windowControllers.first!.window!.contentView!
        try await waitAppearance(nativeWebView(reopenedContent)!, field: "theme", value: "latte")
        try await waitAppearance(nativeWebView(reopenedContent)!, field: "layout", value: "dagre")
        guard nativeEditor(reopenedContent)?.string == manual else { throw Failure("Reopening changed source appearance") }
    }

    private static func themedSource(_ source: String, theme: String, web: WKWebView) async throws -> String {
        guard let updated = try await web.callAsyncJavaScript(
            "return window.macmermaid.editAppearance(source, '', 'theme', theme, palettes)",
            arguments: ["source": source, "theme": theme, "palettes": RenderOptions.palettes],
            in: nil, contentWorld: .page) as? String else { throw Failure("Appearance edit returned no source") }
        return updated
    }

    private static func wait(_ description: String = "WebKit", _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(30)
        while !condition() {
            guard Date() < deadline else { throw Failure("Timed out waiting for \(description)") }
            try await Task.sleep(for: .milliseconds(80))
        }
    }
}
