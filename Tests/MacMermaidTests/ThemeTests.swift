import XCTest
@testable import MacMermaid

final class ThemeTests: XCTestCase {
    func testFreshUnknownAndRemovedAutomaticPreferencesUseStudio() {
        for value in [nil, "unrecognized", "system"] as [String?] {
            XCTAssertEqual(DiagramTheme.preference(value), .studio)
        }
        XCTAssertEqual(RenderOptions().resolvedTheme, .studio)
        XCTAssertEqual(RenderOptions(dark: true).resolvedTheme, .studio)
        XCTAssertFalse(DiagramTheme.allCases.map(\.rawValue).contains("system"))
    }

    func testFixedDiagramPalettesIgnoreAppAppearance() {
        for dark in [false, true] {
            for (theme, expectedDark, background) in [
                ("latte", false, "#eff1f5"), ("mocha", true, "#1e1e2e"),
                ("tokyo-day", false, "#e1e2e7"), ("tokyo-night", true, "#1a1b26")
            ] {
                let options = RenderOptions(theme: theme, dark: dark)
                XCTAssertEqual(options.resolvedTheme.rawValue, theme)
                XCTAssertEqual(options.isDark, expectedDark)
                XCTAssertEqual(options.dictionary["dark"] as? Bool, expectedDark)
                XCTAssertEqual((options.dictionary["palette"] as? [String: String])?["base"], background)
            }
        }
    }

    func testMigrationPreservesExplicitChoicesIncludingLegacyMermaidAuto() throws {
        let suite = "MacMermaid.ThemeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        DiagramTheme.migratePreference(in: defaults)
        XCTAssertNil(defaults.object(forKey: "diagramTheme"))
        defaults.set("system", forKey: "diagramTheme")
        DiagramTheme.migratePreference(in: defaults)
        XCTAssertEqual(defaults.string(forKey: "diagramTheme"), "studio")
        for raw in ["latte", "mocha", "studio", "ocean", "auto", "forest", "neutral", "dark", "tokyo-day", "tokyo-night"] {
            defaults.set(raw, forKey: "diagramTheme")
            DiagramTheme.migratePreference(in: defaults)
            let reloaded = try XCTUnwrap(UserDefaults(suiteName: suite))
            let theme = DiagramTheme.preference(reloaded.string(forKey: "diagramTheme"))
            XCTAssertEqual(theme.rawValue, raw)
        }
    }
}
