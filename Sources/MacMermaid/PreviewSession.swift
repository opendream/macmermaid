import AppKit
import SwiftUI
import WebKit
import UniformTypeIdentifiers

enum DiagramTheme: String, CaseIterable, Identifiable {
    case studio, ocean, auto, forest, neutral, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .studio: "Studio"
        case .ocean: "Ocean"
        case .auto: "Mermaid"
        case .forest: "Forest"
        case .neutral: "Mono"
        case .dark: "Midnight"
        }
    }
    var colors: [Color] {
        switch self {
        case .studio: [.init(red: 0.55, green: 0.78, blue: 0.69), .init(red: 0.81, green: 0.91, blue: 0.86), .white]
        case .ocean: [.blue.opacity(0.7), .cyan.opacity(0.4), .white]
        case .auto: [.purple.opacity(0.6), .purple.opacity(0.2), .white]
        case .forest: [.green.opacity(0.6), .yellow.opacity(0.3), .white]
        case .neutral: [.gray, .gray.opacity(0.3), .white]
        case .dark: [.init(white: 0.2), .purple.opacity(0.5), .gray]
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case svg, png, pdf
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var contentType: UTType { switch self { case .svg: .svg; case .png: .png; case .pdf: .pdf } }
}

struct RenderOptions: Equatable {
    var theme: String = "studio"
    var dark = false
    var grid = true
    var curve = "basis"
    var dictionary: [String: Any] { ["theme": theme, "dark": dark, "grid": grid, "curve": curve] }
}

@MainActor
final class PreviewSession: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    @Published var ready = false
    @Published var isRendering = true
    @Published var isExporting = false
    @Published var error: String?
    @Published var exportError: String?
    @Published var scale = 1.0
    @Published var milliseconds = 0
    @Published var svg: String?
    @Published var size = CGSize.zero
    @Published var toast: String?
    var filename = "Diagram"
    private(set) var webView: WKWebView!
    private var source = ""
    private var options = RenderOptions()
    private var revision = 0
    private var debounce: Task<Void, Never>?
    var canExport: Bool { ready && !isRendering && !isExporting && error == nil && svg != nil }

    override init() {
        super.init()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(WeakMessageHandler(self), name: "preview")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        if let url = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            error = "The bundled renderer is missing. Rebuild MacMermaid with its Web resources."
            isRendering = false
        }
    }

    func update(source: String, options: RenderOptions, immediately: Bool = false) {
        guard source != self.source || options != self.options || immediately else { return }
        self.source = source
        self.options = options
        revision += 1
        isRendering = true
        debounce?.cancel()
        debounce = Task { [weak self] in
            if !immediately { try? await Task.sleep(for: .milliseconds(250)) }
            guard !Task.isCancelled, let self, self.ready else { return }
            await self.sendRender()
        }
    }

    private func sendRender() async {
        let value: [String: Any] = ["source": source, "options": options.dictionary, "revision": revision]
        do {
            _ = try await webView.callAsyncJavaScript("window.macmermaid.request(payload)", arguments: ["payload": value], in: nil, contentWorld: .page)
        } catch {
            self.error = error.localizedDescription
            isRendering = false
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let data = message.body as? [String: Any], let type = data["type"] as? String else { return }
        if type == "ready" {
            ready = true
            Task { await sendRender() }
            return
        }
        if type == "zoom" { scale = data["scale"] as? Double ?? 1; return }
        guard data["revision"] as? Int == revision else { return }
        switch type {
        case "rendered":
            svg = data["svg"] as? String
            size = CGSize(width: data["width"] as? Double ?? 0, height: data["height"] as? Double ?? 0)
            milliseconds = data["milliseconds"] as? Int ?? 0
            error = nil
            isRendering = false
        case "empty":
            svg = nil; error = nil; size = .zero; isRendering = false
        case "error":
            error = data["message"] as? String ?? "This diagram has a syntax error."
            isRendering = false
        default: break
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Only the packaged preview page can navigate this view.
        let local = navigationAction.request.url?.isFileURL == true
        decisionHandler(local && navigationAction.navigationType == .other ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.error = "Could not load the renderer: \(error.localizedDescription)"; isRendering = false
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false; isRendering = false
        error = "The preview stopped. Use Refresh Preview to reload it."
    }

    func reload() {
        error = nil; isRendering = true
        if !ready { webView.reload() }
        else { update(source: source, options: options, immediately: true) }
    }

    func fit() { webView.evaluateJavaScript("window.macmermaid?.fit()", completionHandler: nil) }
    func zoom(by factor: Double) {
        webView.callAsyncJavaScript("window.macmermaid?.zoom(factor)", arguments: ["factor": factor], in: nil, in: .page, completionHandler: nil)
    }

    func exportedSVG() async throws -> String {
        guard let result = try await webView.callAsyncJavaScript("return window.macmermaid.exportSVG()", arguments: [:], in: nil, contentWorld: .page) as? String else {
            throw CocoaError(.fileWriteUnknown)
        }
        return result
    }

    func exportData(_ format: ExportFormat) async throws -> Data {
        switch format {
        case .svg: return Data(try await exportedSVG().utf8)
        case .png:
            guard let base64 = try await webView.callAsyncJavaScript("return await window.macmermaid.png()", arguments: [:], in: nil, contentWorld: .page) as? String,
                  let data = Data(base64Encoded: base64) else { throw CocoaError(.fileWriteUnknown) }
            return data
        case .pdf:
            let svg = try await exportedSVG()
            return try await PDFExporter().data(svg: svg, size: size)
        }
    }

    func export(_ format: ExportFormat) {
        guard canExport else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(filename).\(format.rawValue)"
        panel.title = "Export \(format.title)"
        panel.prompt = "Export"
        guard let window = webView.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self, self.canExport else { return }
            self.isExporting = true
            Task {
                defer { self.isExporting = false }
                do {
                    let data = try await self.exportData(format)
                    try data.write(to: url, options: .atomic)
                    self.showToast("Exported \(format.title)")
                } catch { self.exportError = error.localizedDescription }
            }
        }
    }

    func copySVG() {
        guard canExport else { return }
        Task {
            do {
                let value = try await exportedSVG()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                showToast("SVG copied")
            } catch { exportError = error.localizedDescription }
        }
    }

    private func showToast(_ value: String) {
        toast = value
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.toast == value { self?.toast = nil }
        }
    }
}

@MainActor
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: PreviewSession?
    init(_ target: PreviewSession) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

struct DiagramPreview: NSViewRepresentable {
    @ObservedObject var session: PreviewSession
    func makeNSView(context: Context) -> WKWebView { session.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

@MainActor
private final class PDFExporter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var view: WKWebView!
    func data(svg: String, size: CGSize) async throws -> Data {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        view = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
        view.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            view.loadHTMLString("<html><head><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:\"><style>html,body{margin:0;padding:0;}svg{display:block;max-width:none!important;}</style></head><body>\(svg)</body></html>", baseURL: nil)
        }
        let pdf = WKPDFConfiguration()
        pdf.rect = CGRect(origin: .zero, size: size)
        return try await view.pdf(configuration: pdf)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume(); continuation = nil
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error); continuation = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error); continuation = nil
    }
}
