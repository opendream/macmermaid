# v0.2.0-alpha validation

The final optimized packaged run completed with `SUCCESS`. This record covers the six implementation issues in [milestone v0.2.0-alpha](https://github.com/opendream/macmermaid/milestone/1).

Tested implementation: [59c9b5e](https://github.com/opendream/macmermaid/commit/59c9b5e4107230577fd2edc588e591c61bed3833).
The committed implementation files match the input hashes from the passing run.

## Environment and reproducibility

Checked on 18 October 2026 using arm64 macOS 27.0.1 (26A434), Swift 6.4,
and Node.js 22.19.0. The deployment target remains macOS 26; a macOS 26 runtime
was not available for this run.

The renderer is Mermaid 12.2.0, with SHA-256
`a8a6a6f805b074a8261a2825c86f99c8054acb3b35f50bb7e24a4f9f2c3c3b9f`.
The vendored YAML 2.9.1 bundle rebuilds to its audited checksum using the pinned
npm lockfile. Ordinary builds and rendering need no npm installation.


Local evidence from the completed run:

- `build/v12-final-unit.log` — 9 Swift and 8 JavaScript tests passed.
- `build/v12-final-build.log` — optimized build and 97-notice source/packaged checks passed.
- `build/smoke-v12-final-r8/results.txt` — completed with `SUCCESS`; exports and 20 normal/minimum workspace captures are in the same directory.
- `build/v12-tested-inputs.json` — exact input-file and executable hashes.

Source-input SHA-256: `1e47e54b69fd3d6dd22298e75923d846e9abcb74804cf1812bc43d9a3be1fe12`.
Release executable SHA-256: `edbf72b8bfdf2c24427bc771db2357bc03dabae1cfbe7704de31b4b36ab075c1`.
The source digest hashes sorted `path + NUL + file-SHA256 + newline` records for
`Package.swift`, `Info.plist`, files under `Sources`, `Tests`, `scripts` (excluding
`node_modules`), `third-party`, and `THIRD_PARTY_NOTICES.md`. Build outputs remain
local; the source digest and checked-in screenshot make this record attributable
without committing temporary logs or test documents.

## Milestone coverage

| Issue | Implementation and evidence |
| --- | --- |
| [#8](https://github.com/opendream/macmermaid/issues/8) Renderer | Local 12.2.0 distribution, native defaults, shared version metadata, strict rendering/CSP, 97 component notices, top-level and nested source-map inventory, and separate ELK source/notice audit. |
| [#9](https://github.com/opendream/macmermaid/issues/9) Documents | YAML AST editing preserves comments, unrelated/nested settings, Unicode and body text; source drives inspector state. Tests cover malformed input, Default, native undo/redo, autosave, save/reopen, and two independent documents. All six custom palettes also render on a standalone page containing only upstream Mermaid. |
| [#10](https://github.com/opendream/macmermaid/issues/10) Inspector | Redux Color default plus ten alternatives, supported layout/look choices, Default/Custom, and effective source configuration. Dagre connection choices produce three distinct sets of paths; ineffective controls are hidden. App/editor preferences remain independent. |
| [#11](https://github.com/opendream/macmermaid/issues/11) Templates | Horizontal and vertical swimlanes plus UML use cases; 15 templates total. Tests cover UTF-16 highlighting, names, actual renderer types, and every template/theme combination. The gallery uses the native new-document action. |
| [#12](https://github.com/opendream/macmermaid/issues/12) Validation | Swift/JavaScript units, optimized packaged WebKit run, native document lifecycle, supported configurations, source precedence, errors/rapid edits, exports and visual review. Project-plan date spacing and mind-map branch colors have regression assertions. |
| [#13](https://github.com/opendream/macmermaid/issues/13) Documentation | README, usage/development guides, dependency procedure, version/counts, and a fresh unedited default-theme app capture. Relative links and GitHub-rendered Markdown structure checked. |

## Test coverage

- `./scripts/test.sh`: 9 Swift tests and 8 JavaScript tests.
- `./scripts/build.sh release`: optimized app, source and packaged license checks.
- Packaged suite: 15 templates × 11 themes (165 combinations), plus supported
  layout/look combinations, three distinct Dagre curve paths, and source overrides.
- 105 SVG/PNG/PDF export operations: every template in Redux Color and Mocha,
  four fixed palettes, and recovery output. PDFs are decoded and rasterized for
  review; PNGs are decoded; fixed-palette background samples are checked.
- Native editing, undo/redo, autosave, manual frontmatter edits, save/reopen,
  independent open documents, normal/minimum windows, and app light/dark settings.
  The smoke run starts the real inspector open; visible toolbar interactions are
  checked separately, avoiding reliance on the incomplete in-process accessibility tree.
- Local script URLs and a CSP-blocked fetch check the offline policy. The network
  interface was not disabled. Six standalone palette renders use no app helpers.

Visual review covered both swimlane orientations, UML use cases, flowcharts,
sequence/class diagrams, project plans, mind maps, pie charts, and timelines.
Readability fixes include weekly project-plan ticks and explicit standard color
scales for custom palettes, avoiding Mermaid's derived black mind-map branches.

Visible native checks exercised layout selection, conditional connection controls,
keyboard undo/redo, theme selection with the editor hidden, theme previews, the
15-item template gallery, and the horizontal swimlane inspector. These complement
in-process lifecycle checks; they are not a complete accessibility audit.

## Limits

- Mermaid 12 geometry is intentional; no v11 visual compatibility layer is present.
- Explicit ELK layout fails for mind maps in this upstream version, so the inspector
  retains their native layout. Swimlanes also keep their own algorithm.
- A swimlane return arrow directly into a decision diamond can detach upstream.
  The supplied examples return to a review rectangle before the decision instead.
- YAML aliases, anchors, merge keys and legacy init directives require source edits;
  the inspector explains this and leaves them intact. Unrelated typography variables
  survive Default and may keep the displayed theme Custom.
- Some native diagram strokes, including the timeline baseline, retain upstream
  colors. Custom palettes do not override every diagram-specific drawing rule.
- External screen capture intermittently failed during further gallery-window checks.
  Horizontal template opening was observed directly; all three new template sources
  passed rendering/export checks and use the same native new-document action.
- AppKit snapshots flatten some Liquid Glass materials. The README image is an
  unedited capture; it is layout evidence, not a replacement for live app inspection.
- Builds are locally ad hoc signed. No release tag, binary publication, Developer ID
  signing, notarization, merge, or macOS 26 runtime validation is implied.
