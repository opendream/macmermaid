import SwiftUI
import AppKit

@main
struct MacMermaidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        DocumentGroup(newDocument: MermaidDocument()) { file in
            WorkspaceView(document: file.$document, fileURL: file.fileURL)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        }
        .defaultSize(width: 1260, height: 820)
        .windowToolbarStyle(.unified)
        .commands { MermaidCommands() }

        Settings { SettingsView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--smoke-test"), arguments.count > index + 1 {
            let directory = arguments[index + 1]
            Task { @MainActor in await SmokeTest.run(directory: directory) }
        } else if let directory = Bundle.main.object(forInfoDictionaryKey: "MacMermaidSmokeDirectory") as? String {
            Task { @MainActor in await SmokeTest.run(directory: directory) }
        }
    }
}

struct WorkspaceActions {
    var session: PreviewSession
    var showTemplates: () -> Void
    var toggleEditor: () -> Void
    var toggleInspector: () -> Void
}

struct WorkspaceActionsKey: FocusedValueKey { typealias Value = WorkspaceActions }
extension FocusedValues {
    var workspace: WorkspaceActions? {
        get { self[WorkspaceActionsKey.self] }
        set { self[WorkspaceActionsKey.self] = newValue }
    }
}

struct MermaidCommands: Commands {
    @FocusedValue(\.workspace) private var workspace
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New from Template…") { workspace?.showTemplates() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(workspace == nil)
        }
        CommandGroup(after: .saveItem) {
            Menu("Export Diagram") {
                ForEach(ExportFormat.allCases) { format in
                    Button(format.title) { workspace?.session.export(format) }
                }
            }.disabled(workspace?.session.canExport != true)
            Button("Copy SVG") { workspace?.session.copySVG() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(workspace?.session.canExport != true)
        }
        CommandGroup(after: .textEditing) {
            Button("Find…") { showFind(.showFindInterface) }.keyboardShortcut("f")
            Button("Find and Replace…") { showFind(.showReplaceInterface) }
                .keyboardShortcut("f", modifiers: [.command, .option])
        }
        CommandGroup(after: .toolbar) {
            Button("Toggle Editor") { workspace?.toggleEditor() }
                .keyboardShortcut("e", modifiers: [.command, .option])
            Button("Toggle Inspector") { workspace?.toggleInspector() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
            Button("Zoom In") { workspace?.session.zoom(by: 1.2) }.keyboardShortcut("+")
            Button("Zoom Out") { workspace?.session.zoom(by: 1 / 1.2) }.keyboardShortcut("-")
            Button("Fit Diagram") { workspace?.session.fit() }.keyboardShortcut("0")
        }
        CommandGroup(replacing: .help) {
            Link("Mermaid Syntax Reference", destination: URL(string: "https://mermaid.js.org/intro/")!)
        }
    }

    private func showFind(_ action: NSTextFinder.Action) {
        let item = NSMenuItem()
        item.tag = action.rawValue
        NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: item)
    }
}

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("editorFontSize") private var fontSize = 14.0
    @AppStorage("lineWrap") private var lineWrap = true
    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Slider(value: $fontSize, in: 11...22, step: 1) {
                Text("Editor text · \(Int(fontSize)) pt")
            }
            Toggle("Wrap long lines", isOn: $lineWrap)
            LabeledContent("Rendering", value: "Mermaid 11.16.1 · Offline")
            Text("Your diagrams stay on your Mac. Saved documents use macOS autosave and version history.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 280)
    }
}
