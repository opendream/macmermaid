import XCTest
@testable import MacMermaid

final class DocumentTests: XCTestCase {
    func testUTF8RoundTripPreservesUnicodeAndWhitespace() throws {
        let source = "flowchart TD\n    A[สวัสดี 🌿] --> B[Hello]\n"
        XCTAssertEqual(try MermaidDocument.decode(Data(source.utf8)), source)
    }
    func testReadsUTF8BOM() throws {
        XCTAssertEqual(try MermaidDocument.decode(Data("\u{FEFF}graph LR\nA-->B".utf8)), "graph LR\nA-->B")
    }
    func testRejectsInvalidEncodingWithoutLosingData() {
        XCTAssertThrowsError(try MermaidDocument.decode(Data([0xff, 0xfe, 0x80])))
    }
    func testKindSkipsCommentsAndFrontmatter() {
        XCTAssertEqual(DiagramKind.name(for: "---\ntitle: My flow\n---\n%% comment\nsequenceDiagram\n A->>B: Hi"), "Sequence")
        XCTAssertEqual(DiagramKind.name(for: " \n%% Empty"), "Empty diagram")
    }
    func testHighlightRangesUseUTF16WithUnicodeBeforeKeyword() {
        let text = "%% สวัสดี 🌿\nflowchart TD\nA[\"你好\"] --> B"
        let tokens = MermaidSyntax.tokens(in: text)
        let keywords = tokens.filter { $0.kind == .keyword }.map { (text as NSString).substring(with: $0.range) }
        XCTAssertEqual(keywords, ["flowchart", "TD"])
        XCTAssertTrue(tokens.allSatisfy { NSMaxRange($0.range) <= (text as NSString).length })
    }
}
