# Developing MacMermaid

[Back to the README](../README.md) · [Contributing](../CONTRIBUTING.md)

## Requirements and setup

Use macOS 26 or later, Xcode 26 or later with Swift 6.2+, Git, and Python 3. The Swift package targets macOS 26 and uses Swift 5 language mode with the Swift 6.2 toolchain.

Check which toolchain your shell uses:

```sh
xcode-select -p
xcrun swift --version
python3 --version
```

If command-line builds use a different Xcode installation, select the intended installation under **Xcode → Settings → Locations → Command Line Tools**.

Clone the repository (or your fork), then build:

```sh
git clone https://github.com/opendream/macmermaid.git
cd macmermaid
./scripts/build.sh
open build/MacMermaid.app
```

Open `Package.swift` in Xcode for source development. Use the built `.app` when testing document associations and the native document workflow.

The build script compiles with Swift Package Manager, packages resources and the app icon, includes license notices, and applies an ad hoc signature. It builds for the current Mac's architecture. An optimized build uses:

```sh
./scripts/build.sh release
```

Build outputs go into `.build/` and `build/`, both ignored by Git. Once development tools and the repository are available, builds need no npm installation or CDN access: the Mermaid renderer is vendored.

## Project structure

| Path | Responsibility |
| --- | --- |
| `Sources/MacMermaid/MacMermaidApp.swift` | App lifecycle, commands, and settings |
| `Sources/MacMermaid/WorkspaceView.swift` | Native workspace, toolbar, templates, and inspector |
| `Sources/MacMermaid/CodeEditor.swift` | AppKit text editor, highlighting, and line-number gutter |
| `Sources/MacMermaid/MermaidDocument.swift` | UTF-8 document loading and saving |
| `Sources/MacMermaid/PreviewSession.swift` | WebKit bridge, rendering state, and exports |
| `Sources/MacMermaid/DiagramPalette.swift` | Diagram palette adaptations |
| `Sources/MacMermaid/Resources/Web/` | Bundled Mermaid and local preview HTML, CSS, and JavaScript |
| `Sources/MacMermaid/SmokeTest.swift` | Packaged renderer and document integration checks |
| `Tests/MacMermaidTests/` | Unit tests |
| `third-party/` | License inventory and maintenance procedure |

SwiftUI `DocumentGroup` and `FileDocument` provide the document lifecycle. The source editor is an `NSTextView`; the diagram preview uses a `WKWebView`. Source changes are debounced by 250 ms. The last successful render remains visible during syntax errors, while exports require the current source to render successfully.

The renderer uses a nonpersistent WebKit store, strict Mermaid rendering, a content security policy that blocks network access, and a structured JavaScript bridge. SVG and PNG use a standalone SVG with an explicit background. PDF renders that SVG in a separate local WebKit view, leaving the interactive viewport unchanged.

## Unit tests

```sh
./scripts/test.sh
```

Tests cover UTF-8 document decoding, Unicode syntax highlighting, theme defaults and migration, fixed diagram palettes, and preservation of saved choices.

## Packaged smoke test

Run the smoke suite in its separate app bundle so it uses its own app identifier and preferences:

```sh
./scripts/build.sh
./scripts/prepare-smoke-app.sh
open -n "build/MacMermaid Smoke.app"
```

Wait for that app instance to exit, then read:

```sh
cat build/smoke/results.txt
```

A final `SUCCESS` line confirms completion. Check that the file belongs to the run you just launched; an existing log alone is not proof that a new run succeeded. The smoke app writes exports, snapshots, and test documents under `build/smoke`.

The suite exercises the packaged WebKit renderer across templates and themes, syntax-error recovery, rapid edits, and SVG/PNG/PDF exports. It opens a real native document, inserts Unicode text through the editor, checks autosave, undoes the edit, and saves again. Appearance checks cover System/Light/Dark settings and keep editor appearance independent of the four fixed Catppuccin and Tokyo palettes. The test changes its own app appearance, not macOS appearance settings.

For a custom output directory, the main app also accepts `--smoke-test`:

```sh
open -n build/MacMermaid.app --args --smoke-test "$PWD/build/smoke-custom"
```

That form runs under the main app's identifier. Prefer the separate smoke bundle for routine testing.

## Visual checks and documentation images

Inspect the native app in light and dark appearances at a normal window size and at the minimum size. The smoke suite captures 1260×820 workspaces and inspector-visible 960×540 workspaces; the minimum width with the inspector closed is 820.

Smoke snapshots use AppKit view caching, which can flatten Liquid Glass materials. They are useful layout evidence, but do not replace inspecting the live window and exported files.

The [README image](images/macmermaid.png) is an unedited light-appearance/Latte workspace snapshot from the packaged theme smoke suite. When updating documentation images, use a real app capture with a sample diagram and no private information.

## Third-party dependencies and distribution

Mermaid 11.16.1 and its third-party notices are bundled locally. Follow the [license maintenance procedure](../third-party/README.md) when updating the renderer or palettes.

```sh
python3 scripts/check-licenses.py
python3 scripts/check-licenses.py --app build/MacMermaid.app
```

The build runs these checks before compilation and after packaging. They verify the renderer checksum, notice inventory, and packaged license files. Updating a checksum alone is not a dependency license audit.

Local builds use ad hoc signing. Developer ID signing and notarization are separate steps for distributing a notarized app to other Macs; the build script does not perform them. There are currently no prebuilt GitHub releases.

## References

- [Apple: applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Mermaid API and usage](https://mermaid.js.org/config/usage.html)
- [Third-party notices](../THIRD_PARTY_NOTICES.md)
