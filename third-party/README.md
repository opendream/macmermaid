# Third-party license inventory

`manifest.json` records artifact and source-map hashes, component versions,
license sources, and the full notice-text hashes in `THIRD_PARTY_NOTICES.md`.
It covers Mermaid **12.2.0**, YAML **2.9.1**, and the palette adaptations.

The upstream renderer and source map used for the audit match the exact npm 12.2.0 distribution. The
main map has 1,242 inputs. All 32 embedded parser chunks match the parser 2.0.1
package; their nested maps were inspected too. These maps identify 72 external
package/version pairs. `audit-v12.json` records those pairs, downloaded archives,
checksums, and the separate ELK investigation. The complete inventory has 97
notice entries, including adaptations and prebundled components.

ELK includes Java-derived runtime code, a worker shim, and a Browserify prelude.
Its release build file identifies the GWT, Guava, EMF, Xtend, and Xbase versions.
Their source archives and applicable notices are included conservatively. This
build-file evidence is distinguished from a recovered nested source map; exact
versions are not invented for embedded code that does not expose one. The EPL
entries link to source archives and upstream build instructions.

The source-map inventory is intentionally inclusive: bundling may eliminate an
input. Versions in source paths are stronger evidence than semver dependency
ranges. Unchanged components retain the previous audit's license evidence,
including any explicit limitations about later upstream license snapshots.
DOMPurify uses its Apache-2.0 option. Chevrotain NOTICE and Microsoft third-party
notices are retained. KaTeX's font-derived SVG geometry carries OFL-1.1 notices.
The Mermaid 12.2.0 distribution has a [reproducible lane-spacing patch](patches/README.md) for empty lanes and long headings. The dependency set is unchanged; the manifest records both upstream and shipped checksums. `scripts/patch_mermaid.py` reverses and reapplies the patch to verify exact provenance.

## Rebuilding the YAML bundle

The app builds and runs without npm or network access. Only regenerating the
checked-in YAML browser bundle requires these development tools:

```sh
npm --prefix scripts/web ci --ignore-scripts
npm --prefix scripts/web run build
node --test Tests/Web/*.test.cjs
```

The lockfile pins YAML and esbuild. `Resources/Web/renderer.json` is the version
metadata consumed by Settings, the inspector, and build checks. A regenerated
bundle must match its audited checksum, or receive a new audit before packaging.

## Updating bundled dependencies

1. Obtain the exact distribution and its matching source maps. Compare embedded
   parser chunks with the matching package before inspecting their nested maps.
2. Inventory versions from source paths. Inspect prebundled inputs for additional
   dependencies, adaptations, copyright notices, and upstream NOTICE files.
3. Collect applicable full license texts and source availability references.
   Record uncertain embedded versions honestly. Preserve upstream comments.
4. Update `THIRD_PARTY_NOTICES.md`, license resources, `manifest.json`,
   `audit-v12.json`, and the central `Resources/Web/renderer.json` metadata.
5. Run `python3 scripts/check-licenses.py`, `./scripts/test.sh`, and
   `./scripts/build.sh`. Check the packaged resources with
   `python3 scripts/check-licenses.py --app build/MacMermaid.app`.

The checker verifies checksums, source-map package coverage, metadata consistency,
and packaged files. It cannot determine the license of newly introduced code;
that requires the source review above. No npm cache is needed for these checks.
