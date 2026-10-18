# v0.2.0-alpha validation

**Release held in draft.** Issues #10–#13 remain open until live UI requirements and final documentation are complete. The old tag and assets are retained; the user authorized replacing the tag only after validation. The [withdrawn candidate record](validation/WITHDRAWN-v0.2.0-alpha.md) is historical evidence, not approval of this candidate.

## Current candidate

Build/test inputs: [5e3a661](https://github.com/opendream/macmermaid/commit/5e3a661469d1c86f32b91485f3a5de5c18f61d5f).
Source-input SHA-256: `6816ffe6344aa9cae1b75e2300d4ed6033d851e48bbe53679c9755c4df46c004`.

Mermaid 12.2.0 includes the [documented lane-spacing patch](../third-party/patches/README.md). Shipped renderer SHA-256: `2ef02743353d56e6e04accde7f1ee71061f1d08db83b9f092cd4ac1a42d457af`. YAML remains 2.9.1. The dependency inventory remains 97 notices; the patch adds no dependency and leaves ELK unchanged. Builds verify the patch against the exact original npm checksum.

The source manifest includes committed sources, tests, scripts, dependency records, and CI configuration. Documentation-only commits outside those paths can share evidence if the manifest is identical. `scripts/release_inputs.py` records the complete file list.

## Automated evidence

- Local macOS 27.0.1 (26A434), arm64, Swift 6.4, Node 22.19.0: fresh evidence under `build/alpha-completion/5e3a661/`. The final packaged suite completed with `SUCCESS`; `smoke/resource-bundle-path.txt` confirms resources came from the isolated app bundle.
- macOS 26.6.2 (25G83), arm64, Swift 6.3.3, Node 24.21.0: [matching CI run](https://github.com/opendream/macmermaid/actions/runs/39132052176). The matching run completed successfully, including strict code-signature and embedded-resource checks. This tests the supported major version, not specifically 26.0. The workflow retains OS/toolchain details, input manifest, test/build logs, packaged results, exports and app archive.
- Unit coverage: 9 Swift tests, 12 JavaScript tests, and 9 Python release-check tests.
- Packaged rendering: 15 templates × 11 themes, supported layout/look configurations, three distinct Dagre connection geometries, Default/Custom/source precedence, malformed frontmatter and recovery.
- Exports: 105 existing SVG/PNG/PDF operations plus six swimlane-spacing SVG fixtures, with decoding, palette/background and geometry checks. Representative horizontal Redux Color and vertical Mocha/PDF swimlane exports were visually inspected after the patch.
- Native document APIs: open, Unicode edit, autosave, appearance undo/redo, save/reopen and independent documents. These do not establish keyboard or gallery interaction.
- Offline policy: local scripts and a CSP-blocked fetch; no claim that the network interface was disabled. The suite also asserts resources load from the packaged app, not a SwiftPM build-directory fallback.

An earlier macOS 26 run exposed a packaging-check assumption: SwiftPM 6.3.3 emits a flat resource bundle, while the local 6.4 build uses `Contents/Resources`. The checker now accepts exactly one valid layout. Explicit Bash pipe failure handling also prevents `tee` from hiding a failed build. A subsequent baseline run passed, but the new resource-isolation assertion then exposed a build-directory fallback in SwiftPM 6.3.3. The app now resolves its embedded resource bundle explicitly through `AppResources`; the assertion remains in the suite. Earlier runtime results do not establish portable packaging. Only the matching current run establishes this candidate's macOS 26 result.

The original CI app executable SHA-256 is `68251bf580665280d8a1d5fdf19d8fb056b7e6b2c3e09112e56fcdd5b02d18a5`. An isolated copy of that package also completed the full suite on macOS 27.0.1, with resources loaded from its own embedded bundle. Its identifier/signature were changed for test isolation; the original CI archive is preserved. Non-private evidence is staged under `build/alpha-completion/final-validation/`; its report explicitly leaves live checks blocked.

Relative documentation links and GitHub-rendered HTML structure passed for eight current documents. This is not a live browser visual review.

## Regression results

Fit now scales the full diagram below 5% when necessary. Real WebKit checks cover a 100-node wide diagram in a 400×540 viewport, continuous zoom from Fit, and resizing. Pure geometry tests also cover extremely wide/tall diagrams and small or transiently empty viewports.

Swimlane fixtures include empty first/middle/last lanes, long English and Thai headings, LR/TB and Neo/Classic/Hand-drawn. They assert title containment, separate lane areas, exact visible node/edge/label counts, and removal of temporary layout-only bounds. Hand-drawn bounds allow intentional outline wobble at shared borders. All six cases passed locally on the patched renderer.

A private 29-lane workflow was rechecked against the same renderer in commit 68c8037; subsequent changes only correct notice/provenance text. All 85 node IDs/texts, 29 lane IDs/texts, 106 connections and 67 edge labels match its Mermaid source. All headings fit their title areas and no lane bodies overlap. At 600×800, Fit places the full diagram between x=50 and x=550, at about 3.3% scale. Two renders took 11,244 ms and 11,407 ms. SVG/PNG/PDF exports succeeded. The original positioned SVG has a different layout and some conversion-level differences; preserving Mermaid source is not a claim of exact SVG equivalence. Private source, images and detailed audits remain local and must not enter release assets.

## Remaining release blockers

| Issue | Remaining work |
| --- | --- |
| [#10 Inspector](https://github.com/opendream/macmermaid/issues/10) | Live light/dark, normal/minimum size, theme/look selection and collapse/expand, keyboard focus, accessibility labels and system-accent behavior. |
| [#11 Templates](https://github.com/opendream/macmermaid/issues/11) | Select each new gallery template in the live app; confirm an independent rendered document and unchanged existing unsaved source. |
| [#12 Validation](https://github.com/opendream/macmermaid/issues/12) | Complete live UI/gallery evidence; matching local and macOS 26 automated runs pass. Keep unfinished criteria unchecked. |
| [#13 Documentation](https://github.com/opendream/macmermaid/issues/13) | Final screenshots and validation record after live verification, then documentation/link review. |

Computer Use still reports `Sky Computer Use native pipe startup failed`. AppKit cached-view captures can omit the WebKit canvas or flatten materials, so they are not substituted for a live UI pass. The user is reconnecting Computer Use. The [live UI checklist](validation/LIVE-UI-CHECKLIST.md) records the remaining actions. Existing screenshots are historical until the current candidate is inspected.

## Known limits and publication

- Large swimlane layout remains slow; the lane-spacing fix does not claim to solve performance.
- Return arrows directly into swimlane decision diamonds can still detach upstream. Templates return to a review rectangle before the decision.
- Explicit ELK layout fails for mind maps in this engine; the inspector retains their native layout. Swimlanes keep their dedicated layout.
- YAML aliases/anchors/merge keys and legacy init directives require source edits. Unrelated typography variables survive Default and can leave Custom visible.
- Some diagram-specific strokes retain upstream colors. Look cards are fixed sample illustrations, not thumbnails of the active diagram.
- The release is Apple Silicon, ad hoc signed and unnotarized. No Intel or Developer ID/notarization pass is claimed.

Follow [RELEASING.md](RELEASING.md). `scripts/release_readiness.py` rejects open or incomplete milestone work, missing live UI evidence, stale source/executable/CI provenance and mismatched draft assets. Publication remains blocked until every requirement has evidence. Do not close issues, replace the tag, or publish solely because automated tests pass.
