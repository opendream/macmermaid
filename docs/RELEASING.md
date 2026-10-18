# Completing v0.2.0-alpha

The release is held in draft. Its existing public tag and withdrawn assets are preserved until the replacement candidate passes. The user authorized reusing `v0.2.0-alpha` and replacing the tag **after validation**. Do not publish with unfinished milestone work.

## Evidence required

1. Finish all six milestone issues (#8–#13), including every unchecked acceptance item. Closing an issue as not planned or removing it from the milestone does not satisfy the release check.
2. Run `./scripts/test.sh`, `./scripts/build.sh release`, and a fresh isolated packaged smoke run. The final smoke line must be `SUCCESS`. Keep source and executable hashes with the evidence.
3. Run `.github/workflows/validate.yml` on the same build/test inputs. This uses the macOS 26 runner, records OS/toolchain versions, checks the packaged app, and retains evidence even on failure. It establishes minimum-major-version runtime coverage; it does not establish a live UI pass or specifically test macOS 26.0.
4. Complete live inspector light/dark and normal/minimum-size interactions, keyboard/accessibility, system accent, and all three gallery actions. Use Computer Use or a recorded human review. Direct document APIs and offscreen view captures cannot substitute for these actions.
5. Recheck the representative large swimlane for preserved content and readable lane headings/connections. Private documents and their images must remain local; retain a non-private result summary and the synthetic regression outputs.
6. Update documentation and screenshots from the final candidate, then close the completed milestone. Every issue and checkbox must truthfully reflect the evidence.

## Readiness report

Keep one JSON report in the evidence directory. All evidence paths are relative to that directory and each file includes a SHA-256. Record these fields:

| Field | Value |
| --- | --- |
| `tag` | `v0.2.0-alpha` |
| `testedCommit` | Commit used to build the tested app |
| `sourceInputSHA256` | From `python3 scripts/release_inputs.py --ref <testedCommit>` |
| `testedExecutableSHA256` | SHA-256 of the release app executable before the isolated smoke copy is re-signed |
| `ciRunID`, `ciCommit` | Successful macOS 26 workflow run and its commit |
| `macOS26Environment` | `{ "path": "…", "sha256": "…" }` for the downloaded CI environment record |
| `packagedResults` | Same file-reference format for the final packaged results |
| `appArchive` | Same format for `MacMermaid-v0.2.0-alpha-macos-arm64.zip` |
| `checks` | Entries listed below, each with `status`, `method`, and an `evidence` array of file references |

Required checks: `unit`, `packaged_webkit`, `licenses`, `macos_26_runtime`, `inspector_light_dark`, `inspector_minimum_size`, `keyboard_accessibility`, `system_accent`, `gallery_actions`, and `large_swimlane_readability`. Every status must be `passed`; live UI entries must use method `computer-use` or `human` and identify the exact candidate and actions in their evidence. The script verifies recorded evidence and provenance; a human or agent must still judge whether the observations satisfy each requirement.

The input manifest includes committed sources, tests, scripts, dependency records and CI configuration. Documentation-only commits can share evidence if these inputs remain identical. Both tested commits must be ancestors of the release commit. Uncommitted changes block the check.

```sh
python3 scripts/release_readiness.py --evidence build/final-validation/report.json
```

## Final tag and assets

Only after readiness passes, replace the old annotated tag with the validated release commit, as the user authorized. Preserve the old tag object and withdrawn asset hashes in the validation history. Confirm the remote tag points to the intended commit.

Prepare the final app ZIP, validation ZIP and `SHA256SUMS`. The validation ZIP contains `validation-report.json` (the report without `releaseAssets`) and all referenced check/environment/results files at the same relative paths. Add `releaseAssets` to the external report: an array of `{ "path": "…", "sha256": "…" }` for those three files. The checksum file lists the two ZIPs. Upload these replacements to the existing draft; verify its tag, asset names and hashes.

Use the guarded publication command:

```sh
python3 scripts/release_readiness.py --evidence build/final-validation/report.json --publish
```

It rechecks live GitHub milestone/issue/CI state, local evidence and source provenance, the remote tag, and the exact draft asset hashes and archive contents before publishing a prerelease. Do not replace this with a direct `gh release edit --draft=false` command. Repository administrators can bypass any local script, so this is the required release procedure, not a claim that GitHub itself prevents all manual publication.

The alpha remains ad hoc signed and unnotarized unless the distribution process is deliberately changed. Do not describe it as Developer ID signed or notarized.
