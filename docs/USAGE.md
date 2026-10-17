# Using MacMermaid

[Back to the README](../README.md)

## Documents and editing

Open a `.mmd` or `.mermaid` file, or create a new document with **⌘N**. Files are portable UTF-8 Mermaid source. **⇧⌘N** opens the template picker; selecting a template creates a new document without replacing your current work.

Save a new document once with **⌘S** to choose its location. macOS then manages autosave and document version history. You can open several windows and use **Window → Merge All Windows** to collect them into native tabs.

The editor supports syntax highlighting, line numbers, indentation, undo/redo, find and replace, and line wrapping. Adjust text size and wrapping in **MacMermaid → Settings** or the appearance inspector.

When the source has a syntax error, the last valid preview stays visible. Export and SVG copying become available again after the current source renders successfully.

## Canvas controls

- Drag or scroll to pan.
- Pinch or use **⌘-scroll** to zoom.
- Double-click the canvas or press **⌘0** to fit the diagram.
- Use the floating controls to zoom and fit; the dotted grid can be toggled in the inspector.

## Appearance and themes

**MacMermaid → Settings → Appearance** controls the app and source editor. **System** follows macOS; **Light** and **Dark** override it. The editor keeps its standard syntax colors in each appearance.

The toolbar's appearance inspector contains a **Themes** grid for the diagram canvas and exports:

| Theme | Palette |
| --- | --- |
| Studio | Default MacMermaid theme |
| Ocean | Blue |
| Mermaid | Mermaid's standard theme |
| Forest | Green |
| Mono | Neutral |
| Midnight | Dark |
| Latte | Catppuccin Latte |
| Mocha | Catppuccin Mocha |
| Tokyo Day | Tokyo Night's Day palette |
| Tokyo Night | Tokyo Night's Night palette |

Latte, Mocha, Tokyo Day, and Tokyo Night use fixed palettes independently of app appearance. Diagram themes do not recolor the editor, toolbar, or inspector. Theme and workspace selections persist as app preferences; they are not embedded in `.mmd` files. Mermaid frontmatter and explicit styling in the source may override the inspector's defaults.

New users start with Studio. Upgrading from the earlier Catppuccin Automatic option switches that selection to Studio; explicit saved theme selections are preserved.

The inspector also offers three flowchart connection styles. These apply to flowcharts, not every Mermaid diagram type.

## Export

Choose **File → Export Diagram** for SVG, PNG, or vector PDF. Use **⇧⌘C** to copy SVG to the clipboard.

Exports include the full diagram regardless of the current zoom or pan, with an explicit background and without canvas dots. PNG exports use 2× resolution where possible, capped at 8192 pixels per side and 24 million pixels.

Rendering is local and uses Mermaid 11.16.1. Remote images, clickable diagram links, and remotely loaded icon packs are disabled. The included templates are starting points; the engine supports additional Mermaid diagram types.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New document | ⌘N |
| New from template | ⇧⌘N |
| Open / Save | ⌘O / ⌘S |
| Find / Replace | ⌘F / ⌥⌘F |
| Toggle source editor | ⌥⌘E |
| Toggle appearance inspector | ⌥⌘I |
| Fit diagram | ⌘0 |
| Zoom in / out | ⌘+ / ⌘− |
| Copy SVG | ⇧⌘C |

## Help

Use **Help → Mermaid Syntax Reference** for the [Mermaid documentation](https://mermaid.js.org/intro/). Syntax must be supported by the bundled engine version.

For bugs or feature requests, see the [issue tracker](https://github.com/opendream/macmermaid/issues) and [reporting guidelines](../CONTRIBUTING.md#report-a-bug).
