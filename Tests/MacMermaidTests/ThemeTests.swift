import XCTest
@testable import MacMermaid

final class ThemeTests: XCTestCase {
    func testWorkspaceOptionsContainNoDocumentAppearanceOverrides() {
        let value = RenderOptions(grid: false).dictionary
        XCTAssertEqual(value["grid"] as? Bool, false)
        for name in ["theme", "look", "layout", "curve", "dark"] { XCTAssertNil(value[name]) }
        XCTAssertEqual(RenderOptions.palettes.count, 4)
    }

    func testPaletteTokensAreSharedWithPortableDocumentEditor() {
        for (theme, expectedDark, background) in [
            (DiagramPalette.latte, false, "#eff1f5"), (.mocha, true, "#1e1e2e"),
            (.tokyoDay, false, "#e1e2e7"), (.tokyoNight, true, "#1a1b26")
        ] {
            XCTAssertEqual(theme.isDark, expectedDark)
            XCTAssertEqual(theme.colors["base"], background)
            XCTAssertEqual(RenderOptions.palettes[theme.rawValue], theme.colors)
        }
    }

    func testRendererMetadataAndAvailableThemes() {
        XCTAssertEqual(RendererMetadata.version, "12.2.0")
        XCTAssertEqual(RendererMetadata.checksum.count, 64)
        XCTAssertEqual(DiagramTheme.allCases.count, 11)
        XCTAssertEqual(DiagramTheme.reduxColor.title, "Redux Color")
    }
}
