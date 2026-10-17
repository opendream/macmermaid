import AppKit
import SwiftUI

/// Official palette values: https://catppuccin.com/palette/
/// One source of truth for the native editor and the local Mermaid renderer.
enum CatppuccinPalette: String, CaseIterable {
    case latte, mocha

    var isDark: Bool { self == .mocha }
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

    func syntaxColor(_ kind: MermaidSyntax.Kind) -> NSColor {
        switch kind {
        case .keyword: color("mauve")
        case .string: color("green")
        case .comment: color("subtext0")
        case .arrow: color("teal")
        case .number: color("peach")
        }
    }
}
