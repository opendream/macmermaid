# MacMermaid

A native macOS editor for [Mermaid](https://mermaid.js.org/) diagrams, with live previews and offline rendering.

Write diagram source, see the result as you type, and export it as SVG, PNG, or PDF. MacMermaid combines a native text editor and document workflow with Liquid Glass controls.

![MacMermaid editing a flowchart, with a live preview and Latte selected in the theme inspector.](docs/images/macmermaid.png)

*Light app appearance with the Catppuccin Latte diagram theme.*

**Status:** Early alpha. Build from source using the instructions below; prebuilt downloads are not available yet.

## Features

- **Live preview** with syntax-error feedback and the last valid diagram kept visible while you edit.
- **Native editing** with syntax highlighting, line numbers, find and replace, undo and redo, and line wrapping.
- **Local documents** in `.mmd` and `.mermaid` formats, with autosave, recent files, multiple windows, and native window tabs.
- **Templates and themes:** 12 starting templates and 10 diagram themes, including Catppuccin Latte/Mocha and Tokyo Day/Night.
- **Flexible exports:** SVG, PNG, and vector PDF, plus SVG copying to the clipboard.
- **Offline rendering:** Mermaid is bundled with the app. Rendering needs no account, server, or CDN.

## Get started

### Requirements

- macOS 26 or later.
- Xcode 26 or later, with Swift 6.2 or later available to command-line builds.
- Git and Python 3 (`python3` on your `PATH`).

### Build and run

```sh
git clone https://github.com/opendream/macmermaid.git
cd macmermaid
./scripts/build.sh
open build/MacMermaid.app
```

The script builds and locally signs an app for your Mac's architecture. Once the source and development tools are installed, building and running do not require npm or a network connection.

For an optimized build, use `./scripts/build.sh release`. See the [development guide](docs/DEVELOPMENT.md) for toolchain checks, tests, and packaging details.

## Your first diagram

1. Open a `.mmd` or `.mermaid` file, or press **⌘N** for a new document.
2. Edit the source on the left. The preview updates automatically. Use **⇧⌘N** to start from a template.
3. Press **⌘S** to choose where to save. macOS handles subsequent autosaves.
4. Choose **File → Export Diagram** to export an image, or press **⇧⌘C** to copy SVG.

**MacMermaid → Settings → Appearance** controls the app and editor's light or dark appearance. The toolbar's appearance inspector selects the diagram theme independently.

See the [user guide](docs/USAGE.md) for shortcuts, canvas controls, themes, and export behavior. New to the syntax? Start with the [Mermaid documentation](https://mermaid.js.org/intro/).

## Current limitations

- Rendering uses the bundled **Mermaid 11.16.1** engine; syntax support follows that version.
- Remote images, clickable diagram links, and remotely loaded icon packs are disabled.
- Exports are available only when the current source renders successfully.

## Help and contributions

[Open an issue](https://github.com/opendream/macmermaid/issues) to report a bug or suggest a feature. For rendering problems, include a small Mermaid example and your macOS version.

Bug fixes, documentation, design feedback, and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, reporting guidelines, and checks to run before submitting a change.

MacMermaid is maintained by [Opendream](https://github.com/opendream) and its contributors.

## License and acknowledgments

MacMermaid's original code is licensed under the [MIT License](LICENSE), copyright © 2026 Opendream and MacMermaid contributors.

Thanks to [Mermaid](https://github.com/mermaid-js/mermaid), [Catppuccin](https://github.com/catppuccin/palette), [Tokyo Night](https://github.com/folke/tokyonight.nvim), and their contributors. Bundled third-party components retain their respective licenses; full attributions and license texts are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and included in the app.
