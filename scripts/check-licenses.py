#!/usr/bin/env python3
"""Check notice coverage for the pinned renderer and optional packaged app."""

import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def check(app=None):
    manifest = json.loads((ROOT / "third-party/manifest.json").read_text())
    renderer = manifest["bundle"]
    if sha256((ROOT / renderer["path"]).read_bytes()) != renderer["sha256"]:
        raise ValueError("Renderer changed: audit its dependencies and refresh third-party notices before packaging.")
    web_root = ROOT / "Sources/MacMermaid/Resources/Web"
    metadata = json.loads((web_root / "renderer.json").read_text())
    if (metadata["version"], metadata["sha256"]) != (renderer["version"], renderer["sha256"]):
        raise ValueError("Displayed renderer metadata differs from the audited bundle.")
    for bundle in manifest.get("additionalBundles", []):
        if sha256((ROOT / bundle["path"]).read_bytes()) != bundle["sha256"]:
            raise ValueError(f"Additional bundle changed: {bundle['path']}")
        if bundle["path"].endswith("/yaml.min.js") and bundle["version"] != metadata["yamlVersion"]:
            raise ValueError("YAML version metadata differs from the audited bundle.")
    notices = (ROOT / manifest["notices"]["path"]).read_bytes()
    if sha256(notices) != manifest["notices"]["sha256"]:
        raise ValueError("Third-party notices differ from the audited manifest.")
    text = notices.decode("utf-8")
    seen = set()
    for component in manifest["components"]:
        if component["id"] in seen:
            raise ValueError(f"Duplicate component: {component['id']}")
        seen.add(component["id"])
        marker = f'<a id="{component["noticeAnchor"]}"></a>'
        if text.count(marker) != 1:
            raise ValueError(f"Missing or duplicate notice: {component['id']}")
        section = text.split(marker, 1)[1].split('<a id="component-', 1)[0]
        license_text = section.split("```text\n", 1)[1].split("```", 1)[0]
        if sha256(license_text.encode()) != component["licenseTextSHA256"]:
            raise ValueError(f"License text changed: {component['id']}")
    audit = json.loads((ROOT / "third-party/audit-v12.json").read_text())
    covered = {(c["name"], c["version"]) for c in manifest["components"]}
    for name, version in audit["sourceMapPackageVersions"]:
        if (name, version) not in covered:
            raise ValueError(f"Missing source-map package notice: {name}@{version}")
    if app:
        resources = app / "Contents/Resources"
        for name in ["LICENSE", "THIRD_PARTY_NOTICES.md", "third-party/manifest.json", "third-party/audit-v12.json"]:
            if (resources / name).read_bytes() != (ROOT / name).read_bytes():
                raise ValueError(f"Packaged notice differs: {name}")
        web = resources / "MacMermaid_MacMermaid.bundle/Contents/Resources/Web"
        for name in ["mermaid.min.js", "yaml.min.js", "renderer.json", "palettes.json", "YAML-LICENSE", "MERMAID-LICENSE.txt", "CATPPUCCIN-LICENSE.txt", "TOKYO-NIGHT-LICENSE.txt"]:
            if (web / name).read_bytes() != (ROOT / "Sources/MacMermaid/Resources/Web" / name).read_bytes():
                raise ValueError(f"Packaged renderer resource differs: {name}")
    print(f"License checks passed: {len(seen)} component notices" + (" and packaged resources." if app else "."))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, help="Also verify notices in a built .app")
    args = parser.parse_args()
    try:
        check(args.app)
    except (ValueError, KeyError, IndexError, OSError) as error:
        print(f"License check failed: {error}", file=sys.stderr)
        sys.exit(1)
