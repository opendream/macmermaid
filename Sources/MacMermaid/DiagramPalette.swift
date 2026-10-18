import AppKit
import SwiftUI

/// Diagram-only colors shared by the local renderer, exports, and inspector swatches.
/// Catppuccin: https://catppuccin.com/palette/
/// Tokyo Night: https://github.com/folke/tokyonight.nvim/tree/main/extras/lua
/// The upstream Day/Night colors are adapted to Mermaid roles using the same token
/// names as Catppuccin (for example, mauve = magenta and peach = orange).
/// Catppuccin is MIT licensed and Tokyo Night is Apache-2.0 licensed.
/// Their license texts are bundled in Resources/Web; see THIRD_PARTY_NOTICES.md.
enum DiagramPalette: String, CaseIterable {
    case latte, mocha
    case tokyoDay = "tokyo-day", tokyoNight = "tokyo-night"

    var isDark: Bool { self == .mocha || self == .tokyoNight }
    private static let tokens: [String: [String: String]] = {
        let url = Bundle.module.url(forResource: "palettes", withExtension: "json", subdirectory: "Web")!
        return try! JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
    }()
    var colors: [String: String] { Self.tokens[rawValue]! }

    func color(_ name: String) -> NSColor {
        let hex = colors[name]!
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    var swatches: [Color] { ["mauve", "surface0", "base"].map { Color(nsColor: color($0)) } }

}
