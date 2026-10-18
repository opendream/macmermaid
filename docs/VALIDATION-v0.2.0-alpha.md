# v0.2.0-alpha validation

**Release held in draft.** The premature publication was withdrawn on 18 October
2026. All milestone issues and required checks must be completed before publishing
again. The following record describes the previous candidate, not a release pass
for subsequent fixes. Issues #10, #11, #12 and #13 remain subject to final validation.

The previous optimized packaged test suite completed with `SUCCESS` on 18 October
2026. That automated result did not establish complete interactive UI validation.

Tested implementation: [48c8706](https://github.com/opendream/macmermaid/commit/48c8706b4ae6c7cc883c8b8ebdd2f31a58c109b6).
Subsequent release documentation changes do not alter these compiled inputs.
The withdrawn release's artifacts and tag are retained for traceability. The user
approved reusing v0.2.0-alpha and replacing its tag only after final validation.

## Environment and reproducibility

- Apple Silicon, arm64 macOS 27.0.1 (26A434), Swift 6.4, Node.js 22.19.0.
- Deployment target: macOS 26. No macOS 26 runtime or Intel runtime was tested.
- Mermaid 12.2.0, artifact SHA-256:
  `a8a6a6f805b074a8261a2825c86f99c8054acb3b35f50bb7e24a4f9f2c3c3b9f`.
- YAML 2.9.1, vendored locally with its pinned build inputs and audit metadata.
- Source-input SHA-256:
  `842e61e8a72e37d1fa8f1d7134b113f2be9281ce395291385bfdc554b7687713`.
- Packaged release executable SHA-256:
  `e693ddaffbbe5843ec894185f92dbd13a5411123b7631a033d05e2f3d2d5993b`.

The source digest hashes sorted `path + NUL + file-SHA256 + newline` records for
`Package.swift`, `Info.plist`, `THIRD_PARTY_NOTICES.md`, and files under `Sources`,
`Tests`, `scripts` (excluding `node_modules`), and `third-party`. The evidence
archive contains the complete input manifest. The isolated smoke app is copied
from the release app, given a separate identifier and preferences, and re-signed;
its signature therefore differs from the downloadable app.

Fresh local evidence is under `build/release-v0.2.0-alpha/`:

- `unit.log`: 9 Swift and 8 JavaScript tests passed.
- `build.log`: optimized build and source/packaged checks for 97 notices passed.
- `smoke-r2/results.txt`: final `SUCCESS`, with exports and workspace captures.
- `tested-inputs.json`: exact input-file and release executable hashes.

The preceding smoke attempt stopped at a foreground-focus assertion after its
renderer/export checks. Commit 48c8706 removes that requirement from checks that
address native document/editor APIs directly. A completely fresh run then passed.
This change does not establish keyboard or accessibility behavior.

## Milestone audit

| Issue | Result and remaining boundary |
| --- | --- |
| [#8 Renderer](https://github.com/opendream/macmermaid/issues/8) | Fulfilled: pinned local 12.2.0, native defaults, centralized metadata, dependency audit, license checks, error recovery and export gating. |
| [#9 Documents](https://github.com/opendream/macmermaid/issues/9) | Fulfilled: comment-preserving YAML edits, portable palettes, source-driven selection, undo/redo, autosave, save/reopen, independent documents and workspace preferences. Native lifecycle checks use direct APIs. |
| [#10 Inspector](https://github.com/opendream/macmermaid/issues/10) | Implemented and automated configuration checks pass. Keep open for live light/dark and minimum-size operation, keyboard/accessibility checks, and interaction with the new collapsible theme/look selectors. |
| [#11 Templates](https://github.com/opendream/macmermaid/issues/11) | All three new templates render/export, with highlighting and accurate labels. Keep open until all three gallery actions are exercised in the live app and shown to preserve the current document. Shared action code and generic document-isolation tests are not that complete interaction check. |
| [#12 Validation](https://github.com/opendream/macmermaid/issues/12) | Automated matrix, lifecycle, exports, recovery and licenses pass; representative exports reviewed. Keep open for the outstanding live UI/keyboard/accessibility and gallery checks. |
| [#13 Documentation](https://github.com/opendream/macmermaid/issues/13) | Updated defaults, portable settings, 15 templates, visual selectors, current native screenshot, build/distribution instructions and explicit validation limits. |

## Passing coverage

- `./scripts/test.sh`: 9 Swift and 8 JavaScript tests.
- `./scripts/build.sh release`: optimized app and source/packaged license checks.
- Packaged WebKit: 15 templates × 11 themes = 165 combinations, plus supported
  layout/look configurations, three distinct Dagre connection geometries, source
  precedence, Default removal, Custom state and malformed-frontmatter recovery.
- 105 SVG/PNG/PDF export operations: every template in Redux Color and Mocha,
  four fixed palettes, and recovery output. PNG decoding, PDF decoding/rasterization,
  palette/background samples and geometry assertions supplement visual inspection.
- Native document open, Unicode edit, autosave, appearance undo/redo, manual
  frontmatter edits, save/reopen and two independent documents, through native APIs.
- App/editor preference isolation and System/Light/Dark configuration assertions.
- Local script URLs and a CSP-blocked fetch check the offline policy. The network
  interface was not disabled. Six custom palettes render in standalone Mermaid
  without MacMermaid helpers.
- Syntax errors preserve the last valid preview and disable exports; rapid edits
  recover to the latest source; empty source clears the preview.

Fresh visual inspection covered both swimlane orientations, UML use cases,
sequence and class diagrams, project-plan date spacing, and mind-map output,
including PDF rasterizations. Labels and arrows in those samples were readable.
The exact portable-appearance example in the usage guide also rendered in a
separate headless WebKit check with the pinned bundle; its SVG and PNG were
inspected. Relative documentation links and all six pages' GitHub-rendered HTML
structure were checked. An interactive browser preview was unavailable.
The light, normal-size workspace capture used in the README is an unedited native
AppKit capture of the current build with a non-private sample diagram.

The suite produced 20 normal/minimum-size workspace captures, but some dark
captures omit the WebKit canvas and flatten toolbar materials. These are not proof
that the live dark/minimum-size interface passes, nor evidence by themselves of a
runtime canvas defect. Final live inspection was not completed. Prior-build UI
observations are not substituted for validation of the current selectors.

## Known limitations

- Mermaid 12 geometry is intentional; no v11 compatibility layer is present.
- Large swimlanes can be slow. A separate 85-step, 106-connection, 29-lane case
  took approximately 12–13 seconds; it preserved source content but produced two
  malformed empty lanes and overlapping long role headings. That user document
  and its private artifacts are not included in the release evidence.
- A return arrow directly into a swimlane decision diamond can detach upstream.
  The supplied templates return to a review rectangle before the decision.
- Fit has a 5% minimum zoom, so a very wide diagram can remain clipped in a narrow
  preview. SVG export retains the full diagram.
- Explicit ELK layout fails for mind maps in this engine, so the inspector keeps
  their native layout. Swimlanes also retain their dedicated layout.
- YAML aliases, anchors, merge keys and legacy init directives require source edits;
  the inspector explains this and leaves them intact. Unrelated typography variables
  survive Default and can leave the theme displayed as Custom.
- Some native diagram strokes retain upstream colors; palette variables do not
  override every diagram-specific drawing rule.
- Look cards are fixed native sample illustrations, not rendered thumbnails of
  the current document. They demonstrate drawing style, independently of its palette.
- Full live keyboard/accessibility, light/dark and minimum-window validation remains
  open in the milestone, along with the three gallery-action checks.

## Distribution

`MacMermaid-v0.2.0-alpha-macos-arm64.zip` is an Apple Silicon build for macOS 26+.
It is **ad hoc signed, not Developer ID signed or notarized**. macOS may block its
first launch. No Intel binary, macOS 26 runtime pass, or notarization is claimed.
The source build remains available through the documented build procedure.
