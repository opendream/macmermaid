# MacMermaid

A native macOS workspace for thinking in diagrams. Write Mermaid on the left and see it render on the right, with Liquid Glass controls and an entirely local renderer.

## Run

Requires macOS 26 or later and Xcode 26 or later (Swift 6.2+).

```sh
./scripts/build.sh
open build/MacMermaid.app
```

The app bundle is built for your Mac's architecture and signed locally. To build an optimized version, run `./scripts/build.sh release`. For source development, open `Package.swift` in Xcode. Use the bundled `.app` for testing document associations and the full native document workflow.

## Features

- Native SwiftUI window, Liquid Glass toolbar and floating canvas controls.
- Resizable AppKit source editor with syntax highlighting, line numbers, indentation, undo/redo, find and replace, adjustable text size, and line wrapping.
- Live rendering with a 250 ms debounce. Syntax errors preserve the last valid preview; export is disabled until the current text renders successfully.
- Local `.mmd` and `.mermaid` documents, multiple windows, native window tabs, recent files, autosave, and macOS document version support. Use **Window → Merge All Windows** to collect documents into tabs.
- Twelve templates, each opening a new document rather than replacing your work.
- Catppuccin Latte/Mocha for the editor and diagram canvas, following system appearance by default, with persistent manual choices. Six original diagram themes remain available. Three flowchart connector styles and an optional dotted canvas.
- Pan by dragging or scrolling. Pinch or Command-scroll to zoom. Double-click the canvas to fit.
- SVG, PNG, and vector PDF export; copy SVG to the clipboard. Exports contain the complete diagram, independent of the current zoom or pan, without canvas dots. PNG exports use 2× resolution where possible, capped at 8192 pixels per side and 24 million pixels.

Save a new document once with **⌘S** to choose its location; macOS then manages autosave. App appearance is in **MacMermaid → Settings**. Color themes and connector styles are in the toolbar's appearance inspector. **Automatic** uses Catppuccin Latte in light appearance and Mocha in dark appearance, updating both source highlighting and the canvas as appearance changes. Select **Latte** or **Mocha** to pin a palette independently of app appearance; this choice survives relaunches. Existing explicit theme choices are preserved. The native toolbar and inspector keep their system appearance. Palette values come from the [official Catppuccin palette](https://catppuccin.com/palette/).

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

## Implementation

SwiftUI `DocumentGroup` and `FileDocument` provide the native document lifecycle. The source editor is an `NSTextView`; only the diagram renderer uses `WKWebView`. Mermaid **11.16.1** is vendored in the app, so running and building do not need npm or a CDN. This version was available locally and is pinned deliberately; syntax added in Mermaid 12 is not included.

The renderer uses a nonpersistent WebKit store, strict Mermaid rendering, a content security policy that blocks network access, and a structured JavaScript bridge. Remote images, clickable links in diagrams, and remotely loaded icon packs are not enabled. Diagram frontmatter can configure Mermaid; explicit diagram configuration may override the inspector's defaults. The standard Mermaid engine supplies diagram types beyond the included templates.

SVG and PNG use a standalone SVG with an explicit background. PDF renders that SVG in a separate local WebKit view, keeping the interactive viewport unchanged. Theme and workspace choices are app preferences; `.mmd` files remain portable UTF-8 Mermaid source.

References: [Apple Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [Mermaid API](https://mermaid.js.org/config/usage.html). Mermaid and its bundled third-party notices are preserved in `Sources/MacMermaid/Resources/Web/`.

## Verification

```sh
./scripts/test.sh
./scripts/build.sh
open -n build/MacMermaid.app --args --smoke-test "$PWD/build/smoke"
cat build/smoke/results.txt
```

The smoke test uses the actual packaged WebKit renderer, renders every template and theme, checks syntax-error recovery and rapid edits, exports all three formats, and writes export artifacts plus a preview snapshot. It also opens a real native document, inserts Unicode text through the editor, verifies autosave on disk, undoes the edit, and saves again. It exits its own app instance when finished. A `SUCCESS` line confirms completion. Unit tests cover UTF-8 document decoding, syntax highlighting with Unicode, automatic theme resolution, and preservation of saved theme choices. The smoke suite also exercises both Catppuccin palettes across every template, verifies palette colors in SVG/PNG/PDF exports, and checks live editor/canvas appearance changes and manual overrides in a native document window. It saves native workspace snapshots in both appearances at 1260×820 and the inspector-visible minimum of 960×540 (820×540 with the inspector closed).

If your launcher cannot pass arguments, run `./scripts/prepare-smoke-app.sh` after building, then open `build/MacMermaid Smoke.app`. This separate test bundle uses its own app identifier and automatically writes results to `build/smoke`.

Verified on macOS 27.0.1 with Xcode 27: eight unit tests and the packaged smoke suite pass. PNG/PDF exports and native toolbar/inspector snapshots were visually inspected in both appearances at normal and minimum supported window sizes. The smoke test changes only its own app appearance; it does not change macOS appearance settings.

The bundle uses ad hoc signing for local use. Distribution to other Macs would require a Developer ID signature and notarization.
