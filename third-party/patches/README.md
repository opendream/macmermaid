# Mermaid 12.2.0 lane spacing

MacMermaid applies two narrowly scoped changes to the upstream Mermaid 12.2.0 bundle. No dependency is added or removed, and Mermaid syntax and document source are unchanged.

1. Measure plain swimlane headings at their natural width, using the existing `unwrapGroupLabels` behavior. Other diagram types retain their original measurement.
2. Reserve space for each top-level lane using a temporary geometry-only child. This lets the native swimlane algorithm retain empty lanes and make room for long rotated headings. The temporary nodes are removed before painting and are absent from SVG output and source. Original node and edge objects retain the geometry computed by Mermaid. TB and LR require different temporary heights because LR rotates positions without rotating node shapes.

The changes target `createGraphWithElements` and `runSwimlaneLayoutCore`, identified from the audited upstream source map. The source map still describes upstream code; it is dependency-audit evidence, not a debugging map for the patched bundle. This patch is specific to 12.2.0 and must be reviewed when upgrading Mermaid. No claim is made that another Mermaid installation will produce the same improved lane spacing.

The readable adjustment is [swimlane-space.js](swimlane-space.js). To reproduce:

```sh
python3 scripts/patch_mermaid.py --input /path/to/mermaid-12.2.0/dist/mermaid.min.js
python3 scripts/patch_mermaid.py
```

The script requires the original SHA-256 `a8a6a6f805b074a8261a2825c86f99c8054acb3b35f50bb7e24a4f9f2c3c3b9f`. Verification reverses the two substitutions and checks that exact upstream hash, then reapplies them byte for byte. License checks run this verification. `third-party/manifest.json` and `renderer.json` record the resulting shipped checksum.

Regression coverage checks empty first/middle/last lanes, long English and Thai headings, LR/TB, each look, and preservation of visible nodes and edges in real WebKit. The user's private 29-lane diagram is used only for local comparison and is not included in the repository or release evidence.
