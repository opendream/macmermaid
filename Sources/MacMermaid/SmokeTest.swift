import AppKit
import Foundation

/// Runs the real packaged WebKit renderer; invoked only by the explicit smoke-test flag.
@MainActor
enum SmokeTest {
    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    static func run(directory: String) async {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        var results: [String] = []
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
            results.append("SUCCESS")
        } catch {
            results.append("FAIL: \(error)")
        }
        try? results.joined(separator: "\n").write(to: folder.appendingPathComponent("results.txt"), atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }

    private static func checkNativeDocument(in folder: URL) async throws {
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
        try await wait { document.windowControllers.first?.window?.contentView != nil }
        guard let content = document.windowControllers.first?.window?.contentView else { throw Failure("No document view") }
        func findEditor(_ view: NSView) -> SourceTextView? {
            if let editor = view as? SourceTextView { return editor }
            return view.subviews.lazy.compactMap { findEditor($0) }.first
        }
        try await wait { findEditor(content) != nil }
        guard let editor = findEditor(content), editor.string == original else { throw Failure("Native open changed the source") }
        editor.window?.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: (original as NSString).length, length: 0))
        let addition = "\n%% Autosave round trip · สวัสดี 🌿\n"
        editor.insertText(addition, replacementRange: editor.selectedRange())
        try await wait { document.isDocumentEdited }
        try await document.autosave(withImplicitCancellability: false)
        guard try String(contentsOf: url, encoding: .utf8) == original + addition else { throw Failure("Autosave lost editor changes") }
        editor.undoManager?.undo()
        try await wait { editor.string == original }
        try await document.save(to: url, ofType: "app.macmermaid.diagram", for: .saveOperation)
        guard try String(contentsOf: url, encoding: .utf8) == original else { throw Failure("Undo was not saved correctly") }
    }

    private static func wait(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(30)
        while !condition() {
            guard Date() < deadline else { throw Failure("Timed out waiting for WebKit") }
            try await Task.sleep(for: .milliseconds(80))
        }
    }
}
