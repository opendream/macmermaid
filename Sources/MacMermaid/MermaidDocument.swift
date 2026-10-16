import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let mermaid = UTType(exportedAs: "app.macmermaid.diagram", conformingTo: .plainText)
}

struct MermaidDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.mermaid, .plainText] }
    static var writableContentTypes: [UTType] { [.mermaid] }
    var text: String

    init(text: String = DiagramTemplate.welcome.source) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> String {
        guard let value = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return value.hasPrefix("\u{FEFF}") ? String(value.dropFirst()) : value
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

enum DiagramKind {
    static func name(for source: String) -> String {
        var inFrontmatter = false
        for line in source.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespaces)
            if line == "---" { inFrontmatter.toggle(); continue }
            if inFrontmatter || line.isEmpty || line.hasPrefix("%%") { continue }
            let names = ["flowchart": "Flowchart", "graph": "Flowchart", "sequenceDiagram": "Sequence",
                         "classDiagram": "Class diagram", "stateDiagram": "State diagram", "erDiagram": "Entity relationship",
                         "gantt": "Gantt chart", "pie": "Pie chart", "mindmap": "Mind map", "timeline": "Timeline",
                         "gitGraph": "Git graph", "journey": "User journey", "architecture": "Architecture", "block": "Block diagram"]
            return names.first(where: { line.hasPrefix($0.key) })?.value ?? "Mermaid diagram"
        }
        return "Empty diagram"
    }
}
