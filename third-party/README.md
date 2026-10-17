# Third-party license inventory

`manifest.json` records the artifact, source-map hashes, component versions,
license sources, and notice-text hashes used for `THIRD_PARTY_NOTICES.md`.
It covers the Mermaid 11.16.1 distribution plus Catppuccin and Tokyo Night palettes.

The renderer was compared byte-for-byte with `mermaid@11.16.1/dist/mermaid.min.js`
from the local npm cache. Its matching source map contains 1,125 source inputs.
The embedded `@mermaid-js/parser@1.2.0` chunks were each compared with the matching
cached files before inspecting their nested maps. The two map levels identify
70 external package/version pairs. Additional entries cover Mermaid and its parser,
prebundled Rough.js dependencies, Venn.js's fmin routines, vscode-uri's embedded
code and webpack helpers, KaTeX adaptations, Cytoscape utilities, JamaJS SVD code,
and the two palette families. This produces 86 notice entries.

This inventory is intentionally inclusive: a source-map input may be eliminated
by bundling. The source paths are stronger version evidence than current installed
dependencies or Mermaid's semver ranges, which can resolve to different versions.
Licenses were copied from matching cached npm packages or identified upstream
sources. For Iconify utils, chevrotain-allstar, and ts-dedent, the license source
is a separate upstream snapshot rather than a claim that it is the exact bundled
source version. The full text and its checksum are retained. For embedded code
whose version is not exposed, no exact version is asserted.

DOMPurify's Apache-2.0 alternative is selected; the original dual-license document
is kept intact. Chevrotain's NOTICE is included. The inspected Tokyo Night,
DOMPurify, and JamaJS repository trees contain no separate NOTICE file. KaTeX's
source attribution for font-derived SVG geometry is retained with the OFL-1.1
text. This change does not add fonts or modify the renderer JavaScript.

## Updating the renderer or palettes

1. Obtain the intended distribution and its matching source maps. Keep the
   renderer and map hashes, and inspect nested bundles rather than assuming the
   top-level package license covers them.
2. Identify package versions from source paths, then collect each applicable
   license, copyright notice, modification notice, and upstream NOTICE file.
   Include adapted or prebundled code and document any version uncertainty.
3. Update the full texts in `THIRD_PARTY_NOTICES.md`, the palette license files,
   and the component entries and hashes in `manifest.json`. Preserve upstream
   license comments in the JavaScript.
4. Run `python3 scripts/check-licenses.py` and `./scripts/build.sh`. Verify a
   release build with `python3 scripts/check-licenses.py --app build/MacMermaid.app`.

The checker detects an unreviewed renderer replacement, missing or altered notice
texts, and missing packaged files. It checks consistency; it does not decide the
license of newly introduced code. No npm cache or network access is required to
build the app or run the checker.
