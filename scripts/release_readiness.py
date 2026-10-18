#!/usr/bin/env python3
"""Fail closed before publishing the alpha: milestone, evidence, CI, and assets."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

from release_inputs import input_manifest

REPO = "opendream/macmermaid"
TAG = "v0.2.0-alpha"
MILESTONE = 1
REQUIRED_ISSUES = set(range(8, 14))
REQUIRED_CHECKS = {
    "unit", "packaged_webkit", "licenses", "macos_26_runtime",
    "inspector_light_dark", "inspector_minimum_size", "keyboard_accessibility",
    "system_accent", "gallery_actions", "large_swimlane_readability",
}
LIVE_CHECKS = {
    "inspector_light_dark", "inspector_minimum_size", "keyboard_accessibility",
    "system_accent", "gallery_actions",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)


def api(path):
    return json.loads(gh("api", f"repos/{REPO}/{path}"))


def verify_milestone(milestone, issues):
    require(milestone["title"] == TAG and milestone["state"] == "closed", "Release milestone is not closed")
    issues = [issue for issue in issues if "pull_request" not in issue]
    require(REQUIRED_ISSUES <= {issue["number"] for issue in issues}, "Required milestone issues are missing")
    for issue in issues:
        label = f'Issue #{issue["number"]}'
        require(issue["state"] == "closed" and issue.get("state_reason") == "completed", f"{label} is unfinished")
        body = issue.get("body") or ""
        require(not re.search(r"(?m)^\s*(?:[-*+]|\d+\.)\s+\[\s\]", body), f"{label} has unchecked criteria")
        if issue["number"] in REQUIRED_ISSUES:
            require(re.search(r"(?im)^\s*[-*+]\s+\[x\]", body), f"{label} has no completed checklist")


def checked_file(root, item):
    path = (root / item["path"]).resolve()
    require(path.is_relative_to(root.resolve()), "Evidence path escapes its directory")
    require(path.is_file() and digest(path) == item["sha256"], f'Missing or changed evidence: {item["path"]}')
    return path


def verify_report(report, current_inputs, root):
    require(report["tag"] == TAG, "Wrong release version")
    require(report["sourceInputSHA256"] == current_inputs["sourceInputSHA256"], "Evidence is for different source inputs")
    checks = report["checks"]
    require(REQUIRED_CHECKS <= checks.keys(), "Required validation checks are missing")
    for name in REQUIRED_CHECKS:
        check = checks[name]
        require(check.get("status") == "passed", f"Validation incomplete: {name}")
        require(check.get("evidence"), f"No evidence for {name}")
        if name in LIVE_CHECKS:
            require(check.get("method") in {"computer-use", "human"}, f"{name} requires actual UI interaction")
        for evidence in check["evidence"]:
            checked_file(root, evidence)
    environment = checked_file(root, report["macOS26Environment"])
    require(re.search(r"ProductVersion:\s+26\.", environment.read_text()), "Minimum-version evidence is not macOS 26")
    smoke = checked_file(root, report["packagedResults"])
    require(smoke.read_text().splitlines()[-1] == "SUCCESS", "Packaged suite did not finish successfully")
    app = checked_file(root, report["appArchive"])
    with zipfile.ZipFile(app) as archive:
        require(archive.testzip() is None, "App archive is corrupt")
        binary = archive.read("MacMermaid.app/Contents/MacOS/MacMermaid")
        require(hashlib.sha256(binary).hexdigest() == report["testedExecutableSHA256"], "Packaged executable differs from tested executable")
    return app


def verify_ci(report, run, inputs):
    require(run["status"] == "completed" and run["conclusion"] == "success", "macOS 26 CI is not successful")
    require(run["path"] == ".github/workflows/validate.yml", "Wrong validation workflow")
    require(run["head_sha"] == report["ciCommit"], "CI revision differs from the recorded run")
    require(inputs["sourceInputSHA256"] == report["sourceInputSHA256"], "CI tested different source inputs")


def verify_assets(report_path, report, release):
    root = report_path.parent
    require(release["draft"] and release["tag_name"] == TAG, "Target release must still be a draft")
    local = {}
    for item in report["releaseAssets"]:
        path = checked_file(root, item)
        require(path.name not in local, "Duplicate release asset")
        local[path.name] = item["sha256"]
    expected = {f"MacMermaid-{TAG}-macos-arm64.zip", f"MacMermaid-{TAG}-validation.zip", "SHA256SUMS"}
    require(set(local) == expected, "Final release requires the app, validation archive, and checksums")
    remote = {asset["name"]: asset.get("digest") for asset in release["assets"]}
    require(remote == {name: f"sha256:{sha}" for name, sha in local.items()}, "Draft assets differ from validated local assets")
    app = report["appArchive"]
    require(local[Path(app["path"]).name] == app["sha256"], "Release app is not the tested app archive")
    validation_item = next(item for item in report["releaseAssets"] if item["path"].endswith("-validation.zip"))
    with zipfile.ZipFile(checked_file(root, validation_item)) as archive:
        require(archive.testzip() is None, "Validation archive is corrupt")
        # The report inside the archive excludes final asset digests to avoid a
        # self-referential archive hash. Everything else must match exactly.
        archived_report = json.loads(archive.read("validation-report.json"))
        require(archived_report == {key: value for key, value in report.items() if key != "releaseAssets"}, "Validation archive describes different evidence")
        evidence = [report["macOS26Environment"], report["packagedResults"]]
        evidence += [item for check in report["checks"].values() for item in check["evidence"]]
        for item in evidence:
            require(hashlib.sha256(archive.read(item["path"])).hexdigest() == item["sha256"], f'Validation archive is missing or changed: {item["path"]}')
    sums_item = next(item for item in report["releaseAssets"] if Path(item["path"]).name == "SHA256SUMS")
    sums = dict((name.lstrip("*"), sha) for sha, name in (line.split(maxsplit=1) for line in checked_file(root, sums_item).read_text().splitlines()))
    require(sums == {name: sha for name, sha in local.items() if name != "SHA256SUMS"}, "SHA256SUMS does not match the final archives")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--publish", action="store_true", help="Publish only after every check and final asset/tag check passes")
    args = parser.parse_args()
    require(not subprocess.check_output(["git", "status", "--porcelain"]), "Commit all changes before release validation")
    report = json.loads(args.evidence.read_text())
    current = input_manifest()
    tested = input_manifest(report["testedCommit"])
    require(tested["sourceInputSHA256"] == current["sourceInputSHA256"], "Tested revision has different inputs")
    subprocess.run(["git", "merge-base", "--is-ancestor", report["testedCommit"], "HEAD"], check=True)
    milestone = api(f"milestones/{MILESTONE}")
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{REPO}/issues?milestone={MILESTONE}&state=all&per_page=100"))
    verify_milestone(milestone, [issue for page in pages for issue in page])
    verify_report(report, current, args.evidence.parent)
    run = api(f'actions/runs/{int(report["ciRunID"])}')
    verify_ci(report, run, input_manifest(run["head_sha"]))
    subprocess.run(["git", "merge-base", "--is-ancestor", run["head_sha"], "HEAD"], check=True)
    print("PASS: milestone, source provenance, required evidence, packaged app, and macOS 26 CI")
    if args.publish:
        tag = api(f"git/ref/tags/{TAG}")["object"]
        if tag["type"] == "tag":
            tag = api(f'git/tags/{tag["sha"]}')["object"]
        require(tag["type"] == "commit" and tag["sha"] == current["commit"], "Remote release tag is not the validated final commit")
        releases = json.loads(gh("api", "--paginate", "--slurp", f"repos/{REPO}/releases?per_page=100"))
        matches = [release for page in releases for release in page if release["tag_name"] == TAG]
        require(len(matches) == 1, "Expected exactly one draft release")
        verify_assets(args.evidence, report, matches[0])
        gh("api", "--method", "PATCH", f'repos/{REPO}/releases/{matches[0]["id"]}', "-F", "draft=false", "-F", "prerelease=true")
        print(f"Published {TAG}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, IndexError, OSError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print(f"Release blocked: {error}", file=sys.stderr)
        sys.exit(1)
