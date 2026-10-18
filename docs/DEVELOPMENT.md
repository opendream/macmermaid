# Developing MacMermaid

[Back to the README](../README.md) · [Contributing](../CONTRIBUTING.md)

## Requirements and setup

Use macOS 26 or later, Xcode 26 or later with Swift 6.2+, Git, and Python 3. Node.js 22+ is needed for the JavaScript tests; rebuilding the vendored YAML bundle also uses npm. The Swift package targets macOS 26 and uses Swift 5 language mode with the Swift 6.2 toolchain.

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
| `Sources/MacMermaid/DiagramPalette.swift` | Swift access to shared palette tokens |
| `Sources/MacMermaid/LookPreview.swift` | Fixed sample illustrations for the look selector |
| `Sources/MacMermaid/RendererMetadata.swift` | Shared renderer version metadata |
| `Sources/MacMermaid/Resources/Web/appearance.js` | Comment-preserving YAML edits and inspector state |
| `Sources/MacMermaid/Resources/Web/palettes.json` | Shared portable palette tokens |
| `Sources/MacMermaid/Resources/Web/` | Bundled Mermaid and local preview HTML, CSS, and JavaScript |
| `Sources/MacMermaid/SmokeTest.swift` | Packaged renderer and document integration checks |
| `Tests/MacMermaidTests/` and `Tests/Web/` | Swift and JavaScript unit tests |
| `third-party/` | License inventory and maintenance procedure |

SwiftUI `DocumentGroup` and `FileDocument` provide the document lifecycle. The source editor is an `NSTextView`; the diagram preview uses a `WKWebView`. Source changes are debounced by 250 ms. The last successful render remains visible during syntax errors, while exports require the current source to render successfully.

The renderer uses a nonpersistent WebKit store, strict Mermaid rendering, a content security policy that blocks network access, and a structured JavaScript bridge. SVG and PNG use a standalone SVG with an explicit background. PDF renders that SVG in a separate local WebKit view, leaving the interactive viewport unchanged.

Diagram settings come from the document source. Inspector actions use the YAML AST editor in the Web view, then perform one native `NSTextView` edit. The source is checked again before applying an asynchronous edit. Renderer-reported diagram types and parsed configuration drive controls; the pinned 12.2 configuration aliases, precedence, and layout fallbacks are mirrored in `appearance.js` and exercised in the packaged tests. Keep these in sync when upgrading Mermaid.

`renderer.json` is the central renderer version/checksum source. Palette tokens live in `palettes.json`, shared by Swift swatches and portable YAML generation. The app does not make global layout/look overrides or restore v11 geometry. Mermaid's native HTML label mode is retained because forcing SVG text labels misaligns use-case labels in this version; exported images are checked in WebKit.

To rebuild the YAML bundle, follow [the dependency instructions](../third-party/README.md#rebuilding-the-yaml-bundle). This is a development operation; ordinary app builds use the checked-in assets.

## Unit tests

```sh
./scripts/test.sh
```

Tests cover UTF-8 decoding, Unicode highlighting, metadata, shared palette tokens, comment-preserving YAML updates, scoped configuration precedence, malformed YAML, Default removal, and Custom states. JavaScript tests exercise the actual bundled YAML parser without npm installation.

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

The suite exercises every template/theme combination, supported layouts and looks, actual Dagre curve geometry, error recovery, rapid edits, and SVG/PNG/PDF exports. It checks project-plan date-label spacing and mind-map branch colors, and saves PDF thumbnails for visual review. A separate page containing only Mermaid verifies the six custom palettes without app helpers. A blocked fetch and local script URLs check the preview's offline policy.

Native documents cover Unicode editing, autosave, appearance undo/redo, manual frontmatter edits, save/reopen, and independent choices in two documents. These checks address document/editor APIs directly and do not require foreground keyboard focus. The explicit smoke run starts its documents with the real inspector visible; separately inspect opening it, interacting with controls, keyboard operation, and accessibility. Appearance assertions cover System/Light/Dark settings and keep editor appearance independent of diagram palettes. The test changes its own app appearance, not macOS appearance settings.

Use a fresh output directory to keep evidence from different builds separate:

```sh
./scripts/prepare-smoke-app.sh "$PWD/build/smoke-v12"
open -n "build/MacMermaid Smoke.app"
cat build/smoke-v12/results.txt
```

The main app also accepts `--smoke-test <absolute-directory>`, but the separate
bundle avoids affecting the main app's preferences.

## Visual checks and documentation images

Inspect the native app in light and dark appearances at a normal window size and at the minimum size. The smoke suite captures 1260×820 workspaces and inspector-visible 960×540 workspaces; the minimum width with the inspector closed is 820.

Smoke snapshots use AppKit view caching, which can flatten Liquid Glass materials or omit WebKit canvas contents. They are limited layout evidence and do not establish live-window usability or accessibility. Inspect the live window and exported files separately; record any checks that could not be completed.

The [README image](images/macmermaid.png) is an unedited light-appearance workspace snapshot with Redux Color and native ELK/Neo defaults from the packaged smoke suite. When updating documentation images, use a real app capture with a sample diagram and no private information.

See [the v0.2.0-alpha validation record](VALIDATION-v0.2.0-alpha.md) for the tested environment, issue coverage, and remaining limits.

## Third-party dependencies and distribution

Mermaid 12.2.0, YAML 2.9.1, and their third-party notices are bundled locally. Follow the [license maintenance procedure](../third-party/README.md) when updating the renderer or palettes.

```sh
python3 scripts/check-licenses.py
python3 scripts/check-licenses.py --app build/MacMermaid.app
```

The build runs these checks before compilation and after packaging. They verify the renderer/YAML checksums, central version metadata, source-map package coverage, notice inventory, and packaged files. Updating a checksum alone is not a dependency license audit.

Local builds use ad hoc signing. The v0.2.0-alpha release is held in draft until all milestone issues and required checks pass. Its intended Apple Silicon ZIP uses ad hoc signing, not Developer ID signing or notarization; the build script does not perform those distribution steps. macOS 26 remains the deployment target. The prior candidate was runtime-tested on macOS 27.0.1; final evidence must include the supported macOS 26 runtime.

The icon generator uses a neutral connected-node design. The build regenerates the ICNS when either icon script changes, rather than retaining a stale cached icon.

## References

- [Apple: applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Mermaid API and usage](https://mermaid.js.org/config/usage.html)
- [Third-party notices](../THIRD_PARTY_NOTICES.md)
