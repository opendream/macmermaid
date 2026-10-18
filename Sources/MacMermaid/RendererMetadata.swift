import Foundation

enum RendererMetadata {
    private struct Metadata: Decodable { let version: String; let sha256: String; let yamlVersion: String }
    private static let metadata: Metadata = {
        guard let url = Bundle.module.url(forResource: "renderer", withExtension: "json", subdirectory: "Web"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(Metadata.self, from: data) else {
            preconditionFailure("The bundled renderer metadata is missing or invalid.")
        }
        return value
    }()
    static var version: String { metadata.version }
    static var checksum: String { metadata.sha256 }
}
