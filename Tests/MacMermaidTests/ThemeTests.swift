import XCTest
@testable import MacMermaid

final class ThemeTests: XCTestCase {
    func testFreshAndUnknownPreferencesFollowAppearance() {
        for value in [nil, "unrecognized"] as [String?] {
            let theme = DiagramTheme.preference(value)
            XCTAssertEqual(theme.resolved(dark: false), .latte)
            XCTAssertEqual(theme.resolved(dark: true), .mocha)
        }
        XCTAssertEqual(RenderOptions().resolvedTheme, .latte)
        XCTAssertEqual(RenderOptions(dark: true).resolvedTheme, .mocha)
    }

    func testManualCatppuccinChoiceIgnoresAppearance() {
        for dark in [false, true] {
            let latte = RenderOptions(theme: "latte", dark: dark)
            XCTAssertEqual(latte.resolvedTheme, .latte)
            XCTAssertFalse(latte.isDark)
            let mocha = RenderOptions(theme: "mocha", dark: dark)
            XCTAssertEqual(mocha.resolvedTheme, .mocha)
            XCTAssertTrue(mocha.isDark)
        }
    }

    func testStoredChoicesSurviveRereadingIncludingLegacyMermaidAuto() throws {
        let suite = "MacMermaid.ThemeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(DiagramTheme.preference(defaults.string(forKey: "diagramTheme")), .system)
        for raw in ["latte", "mocha", "studio", "ocean", "auto", "forest", "neutral", "dark"] {
            defaults.set(raw, forKey: "diagramTheme")
            let reloaded = try XCTUnwrap(UserDefaults(suiteName: suite))
            let theme = DiagramTheme.preference(reloaded.string(forKey: "diagramTheme"))
            XCTAssertEqual(theme.rawValue, raw)
            XCTAssertEqual(theme.resolved(dark: false).rawValue, raw)
            XCTAssertEqual(theme.resolved(dark: true).rawValue, raw)
        }
    }
}
