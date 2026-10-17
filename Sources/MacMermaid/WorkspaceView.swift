import SwiftUI

private let accent = Color(red: 0.18, green: 0.56, blue: 0.48)

struct WorkspaceView: View {
    @Binding var document: MermaidDocument
    let fileURL: URL?
    @StateObject private var session = PreviewSession()
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("editorFontSize") private var fontSize = 14.0
    @AppStorage("lineWrap") private var lineWrap = true
    @AppStorage("diagramTheme") private var theme = DiagramTheme.studio.rawValue
    @AppStorage("showGrid") private var showGrid = true
    @AppStorage("diagramCurve") private var curve = "basis"
    @State private var showTemplates = false
    @State private var showInspector = false
    @State private var showEditor = true
    @State private var line = 1
    @State private var column = 1
    @State private var showErrorDetails = true

    private var options: RenderOptions {
        RenderOptions(theme: theme, dark: colorScheme == .dark, grid: showGrid, curve: curve)
    }

    var body: some View {
        HStack(spacing: 0) {
            HSplitView {
                if showEditor { editorPane.frame(minWidth: 290, idealWidth: 415, maxWidth: 640) }
                previewPane.frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            }
            if showInspector {
                Divider()
                inspector.frame(width: 238)
            }
        }
        .frame(minWidth: showInspector ? 960 : 820, minHeight: 540)
        .tint(accent)
        .background(.background)
        .toolbar { toolbar }
        .sheet(isPresented: $showTemplates) { TemplateGallery() }
        .alert("Couldn’t export diagram", isPresented: Binding(get: { session.exportError != nil }, set: { if !$0 { session.exportError = nil } })) {
            Button("OK") { session.exportError = nil }
        } message: { Text(session.exportError ?? "") }
        .focusedSceneValue(\.workspace, WorkspaceActions(session: session, showTemplates: { showTemplates = true }, toggleEditor: { showEditor.toggle() }, toggleInspector: { showInspector.toggle() }))
        .onAppear { DiagramTheme.migratePreference(in: .standard); render(); updateFilename() }
        .onChange(of: document.text) { render() }
        .onChange(of: options) { render() }
        .onChange(of: fileURL) { updateFilename() }
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundStyle(accent)
                Text("Source").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("MERMAID").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.2).foregroundStyle(.tertiary)
                Menu {
                    Toggle("Wrap Lines", isOn: $lineWrap)
                    Button("Increase Text Size") { fontSize = min(22, fontSize + 1) }
                    Button("Decrease Text Size") { fontSize = max(11, fontSize - 1) }
                    Divider()
                    Link("Syntax Reference", destination: URL(string: "https://mermaid.js.org/intro/")!)
                } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).fixedSize().help("Editor options")
            }
            .padding(.horizontal, 18).frame(height: 46)
            Divider().opacity(0.5)
            CodeEditor(text: $document.text, fontSize: fontSize, wraps: lineWrap, dark: colorScheme == .dark) { newLine, newColumn in
                // NSTextView selection notifications can arrive during a SwiftUI update.
                DispatchQueue.main.async { line = newLine; column = newColumn }
            }
            Divider().opacity(0.5)
            HStack {
                Text("Ln \(line), Col \(column)")
                Spacer()
                Text("\(document.text.components(separatedBy: "\n").count) lines")
                Text("UTF-8").padding(.leading, 8)
            }
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            .padding(.horizontal, 16).frame(height: 30)
        }
        .background(colorScheme == .dark ? Color(red: 0.105, green: 0.135, blue: 0.15) : Color(red: 0.985, green: 0.987, blue: 0.985))
    }

    private var previewPane: some View {
        ZStack {
            DiagramPreview(session: session)
            if document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 36, weight: .light)).foregroundStyle(accent)
                    Text("Room for an idea.").font(.system(size: 25, weight: .medium, design: .rounded))
                    Text("Start writing, or find a little inspiration.").foregroundStyle(.secondary)
                    Button("Choose a Template") { showTemplates = true }.buttonStyle(.glass).padding(.top, 8)
                }
            }
            VStack(spacing: 0) {
                HStack {
                    Label(DiagramKind.name(for: document.text), systemImage: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    renderStatus
                }.padding(.horizontal, 22).padding(.top, 18)
                Spacer()
                if let error = session.error { errorCard(error).padding(.horizontal, 20).padding(.bottom, 12) }
                if let toast = session.toast {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule).padding(.bottom, 12)
                }
                HStack(alignment: .bottom) {
                    Label("On your Mac", systemImage: "lock.shield")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                    Spacer()
                    zoomControls
                    Spacer()
                    Button { showGrid.toggle() } label: { Image(systemName: "circle.grid.3x3.fill").frame(width: 32, height: 32) }
                        .buttonStyle(.plain).foregroundStyle(showGrid ? accent : .secondary)
                        .glassEffect(.regular, in: .circle).help("Toggle canvas grid")
                }.padding(.horizontal, 20).padding(.bottom, 20)
            }
            .allowsHitTesting(true)
        }
        .environment(\.colorScheme, options.isDark ? .dark : .light)
        .overlay {
            if session.isExporting {
                ProgressView("Exporting…").padding(24).glassEffect(.regular, in: .rect(cornerRadius: 20))
            }
        }
    }

    private var renderStatus: some View {
        HStack(spacing: 6) {
            Circle().fill(session.error != nil ? .orange : accent).frame(width: 5, height: 5)
            Text(session.isRendering ? "Rendering" : session.error != nil ? "Check source" : "Live")
            if !session.isRendering && session.error == nil && session.svg != nil {
                Text("· \(session.milliseconds) ms").foregroundStyle(.tertiary)
            }
        }.font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 11).padding(.vertical, 7).glassEffect(.regular, in: .capsule)
    }

    private var zoomControls: some View {
        HStack(spacing: 1) {
            Button { session.zoom(by: 1 / 1.2) } label: { Image(systemName: "minus").frame(width: 30, height: 30) }.help("Zoom out · ⌘−")
            Text("\(Int(session.scale * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced)).frame(width: 46)
            Button { session.zoom(by: 1.2) } label: { Image(systemName: "plus").frame(width: 30, height: 30) }.help("Zoom in · ⌘+")
            Divider().frame(height: 16).padding(.horizontal, 5)
            Button { session.fit() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 30, height: 30) }.help("Fit diagram · ⌘0")
        }.buttonStyle(.plain).padding(4).glassEffect(.regular, in: .capsule)
    }

    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Text(session.svg == nil ? "Let’s check that syntax" : "Showing your last valid diagram")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh preview")
                Button { showErrorDetails.toggle() } label: { Image(systemName: showErrorDetails ? "chevron.down" : "chevron.up") }.help("Toggle error details")
            }.buttonStyle(.plain)
            if showErrorDetails {
                ScrollView { Text(error).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 110)
            }
        }.padding(16).glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { showEditor.toggle() } label: { Label("Toggle Editor", systemImage: "sidebar.left") }
                .help("Toggle editor · ⌥⌘E")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { showTemplates = true } label: { Label("Templates", systemImage: "square.grid.2x2") }.help("New from template · ⇧⌘N")
            Button { showInspector.toggle() } label: { Label("Appearance", systemImage: "slider.horizontal.3") }.help("Diagram appearance · ⌥⌘I")
            Menu {
                ForEach(ExportFormat.allCases) { format in
                    Button("Export \(format.title)…") { session.export(format) }
                }
                Divider()
                Button("Copy SVG") { session.copySVG() }
            } label: { Label("Export", systemImage: "square.and.arrow.up") }
                .disabled(!session.canExport)
                .help("Export your diagram")
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Make it yours").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button { showInspector = false } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)) }.buttonStyle(.plain).foregroundStyle(.secondary).help("Close appearance")
                }
                VStack(alignment: .leading, spacing: 12) {
                    inspectorLabel("THEMES")
                    themeGrid(DiagramTheme.allCases)
                }
                VStack(alignment: .leading, spacing: 12) {
                    inspectorLabel("CONNECTIONS")
                    Picker("Line style", selection: $curve) {
                        Text("Smooth").tag("basis")
                        Text("Straight").tag("linear")
                        Text("Stepped").tag("stepAfter")
                    }.labelsHidden().frame(maxWidth: .infinity)
                    Text("Applies to flowchart connections.").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    inspectorLabel("WORKSPACE")
                    Toggle("Canvas grid", isOn: $showGrid).font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
                    Toggle("Wrap source lines", isOn: $lineWrap).font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
                    HStack {
                        Text("Text size").font(.system(size: 11))
                        Spacer()
                        Stepper("\(Int(fontSize))", value: $fontSize, in: 11...22).font(.system(size: 11)).fixedSize()
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("A space to think clearly.").font(.system(size: 11, weight: .medium, design: .rounded))
                    Text("Mermaid 11.16.1 · Runs offline").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }.background(.bar)
    }

    private func themeGrid(_ themes: [DiagramTheme]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(themes) { option in
                Button { theme = option.rawValue } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                RoundedRectangle(cornerRadius: 4).fill(option.colors[index])
                                    .frame(width: 20, height: 20)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.12)))
                            }
                        }
                        HStack(spacing: 4) {
                            Text(option.title).font(.system(size: 10, weight: .medium))
                                .lineLimit(2).frame(minHeight: 24, alignment: .topLeading)
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                .foregroundStyle(accent).opacity(theme == option.rawValue ? 1 : 0)
                        }
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme == option.rawValue ? accent.opacity(0.1) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme == option.rawValue ? accent.opacity(0.6) : .clear))
                }.buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityValue(theme == option.rawValue ? "Selected" : "Not selected")
            }
        }
    }

    private func inspectorLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(.secondary)
    }
    private func render() { session.update(source: document.text, options: options) }
    private func updateFilename() { session.filename = fileURL?.deletingPathExtension().lastPathComponent ?? "Diagram" }
}

struct TemplateGallery: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.newDocument) private var newDocument
    @State private var search = ""
    private var templates: [DiagramTemplate] {
        DiagramTemplate.all.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.subtitle.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start with a little inspiration.").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("Choose a starting point. Make it your own.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            TextField("Find a template", text: $search).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(templates) { template in
                        Button {
                            dismiss()
                            newDocument(MermaidDocument(text: template.source))
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: template.symbol).font(.system(size: 26, weight: .light)).foregroundStyle(accent).frame(height: 38)
                                Text(template.title).font(.system(size: 13, weight: .semibold))
                                Text(template.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).frame(height: 30, alignment: .top)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
                                .contentShape(RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Text("Each template opens as a new document.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Blank Diagram") { dismiss(); newDocument(MermaidDocument(text: "")) }
            }
        }.padding(30).frame(width: 740, height: 620).tint(accent)
    }
}
