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
    var colors: [String: String] {
        switch self {
        case .latte:
            ["base": "#eff1f5", "mantle": "#e6e9ef", "surface0": "#ccd0da",
             "surface1": "#bcc0cc", "surface2": "#acb0be", "text": "#4c4f69",
             "subtext0": "#6c6f85", "subtext1": "#5c5f77", "overlay1": "#8c8fa1",
             "mauve": "#8839ef", "green": "#40a02b", "peach": "#fe640b",
             "blue": "#1e66f5", "teal": "#179299", "yellow": "#df8e1d",
             "pink": "#ea76cb", "red": "#d20f39", "lavender": "#7287fd",
             "rosewater": "#dc8a78"]
        case .mocha:
            ["base": "#1e1e2e", "mantle": "#181825", "surface0": "#313244",
             "surface1": "#45475a", "surface2": "#585b70", "text": "#cdd6f4",
             "subtext0": "#a6adc8", "subtext1": "#bac2de", "overlay1": "#7f849c",
             "mauve": "#cba6f7", "green": "#a6e3a1", "peach": "#fab387",
             "blue": "#89b4fa", "teal": "#94e2d5", "yellow": "#f9e2af",
             "pink": "#f5c2e7", "red": "#f38ba8", "lavender": "#b4befe",
             "rosewater": "#f5e0dc"]
        case .tokyoDay:
            ["base": "#e1e2e7", "mantle": "#d0d5e3", "surface0": "#c4c8da",
             "surface1": "#b7c1e3", "surface2": "#a8aecb", "text": "#3760bf",
             "subtext0": "#6172b0", "subtext1": "#6172b0", "overlay1": "#68709a",
             "mauve": "#9854f1", "green": "#587539", "peach": "#b15c00",
             "blue": "#2e7de9", "teal": "#118c74", "yellow": "#8c6c3e",
             "pink": "#d20065", "red": "#f52a65", "lavender": "#7847bd",
             "rosewater": "#007197"]
        case .tokyoNight:
            ["base": "#1a1b26", "mantle": "#16161e", "surface0": "#292e42",
             "surface1": "#394b70", "surface2": "#3b4261", "text": "#c0caf5",
             "subtext0": "#a9b1d6", "subtext1": "#a9b1d6", "overlay1": "#737aa2",
             "mauve": "#bb9af7", "green": "#9ece6a", "peach": "#ff9e64",
             "blue": "#7aa2f7", "teal": "#1abc9c", "yellow": "#e0af68",
             "pink": "#ff007c", "red": "#f7768e", "lavender": "#9d7cd8",
             "rosewater": "#7dcfff"]
        }
    }

    func color(_ name: String) -> NSColor {
        let hex = colors[name]!
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    var swatches: [Color] { ["mauve", "surface0", "base"].map { Color(nsColor: color($0)) } }

}
