import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from release_readiness import REQUIRED_CHECKS, LIVE_CHECKS, verify_milestone, verify_report, verify_ci, verify_assets


class ReleaseReadinessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.milestone = {"title": "v0.2.0-alpha", "state": "closed"}
        self.issues = [{"number": n, "state": "closed", "state_reason": "completed", "body": "- [x] Verified"} for n in range(8, 14)]
        note = self.file("ui-review.txt", b"Recorded actual UI interaction")
        environment = self.file("environment.txt", b"ProductVersion:\t26.0\n")
        results = self.file("results.txt", b"PASS\nSUCCESS\n")
        binary = b"tested executable"
        app = self.root / "MacMermaid-v0.2.0-alpha-macos-arm64.zip"
        with zipfile.ZipFile(app, "w") as archive:
            archive.writestr("MacMermaid.app/Contents/MacOS/MacMermaid", binary)
        self.report = {
            "tag": "v0.2.0-alpha", "sourceInputSHA256": "source", "ciCommit": "ci-sha",
            "checks": {name: {"status": "passed", "method": "computer-use" if name in LIVE_CHECKS else "automated", "evidence": [note]} for name in REQUIRED_CHECKS},
            "macOS26Environment": environment, "packagedResults": results,
            "appArchive": {"path": app.name, "sha256": hashlib.sha256(app.read_bytes()).hexdigest()},
            "testedExecutableSHA256": hashlib.sha256(binary).hexdigest(),
        }
        self.inputs = {"sourceInputSHA256": "source"}
        self.run = {"status": "completed", "conclusion": "success", "path": ".github/workflows/validate.yml", "head_sha": "ci-sha"}

    def file(self, name, contents):
        (self.root / name).write_bytes(contents)
        return {"path": name, "sha256": hashlib.sha256(contents).hexdigest()}

    def test_complete_evidence_passes(self):
        verify_milestone(self.milestone, self.issues)
        verify_report(self.report, self.inputs, self.root)
        verify_ci(self.report, self.run, self.inputs)

    def test_open_unchecked_removed_or_uncompleted_issue_blocks(self):
        variants = []
        for changes in [{"state": "open"}, {"state_reason": "not_planned"}, {"body": "- [x] One\n  - [ ] Pending"}, {"body": "No checklist"}]:
            issues = copy.deepcopy(self.issues)
            issues[-1].update(changes)
            variants.append(issues)
        variants.append(self.issues[:-1])
        for issues in variants:
            with self.subTest(issues=issues), self.assertRaises(ValueError):
                verify_milestone(self.milestone, issues)

    def test_open_milestone_blocks(self):
        with self.assertRaises(ValueError):
            verify_milestone({**self.milestone, "state": "open"}, self.issues)

    def test_blocked_missing_or_api_only_ui_evidence_blocks(self):
        for mutation in ["blocked", "missing", "api-only", "no-evidence"]:
            report = copy.deepcopy(self.report)
            check = report["checks"]["gallery_actions"]
            if mutation == "blocked": check["status"] = "blocked"
            if mutation == "missing": del report["checks"]["gallery_actions"]
            if mutation == "api-only": check["method"] = "automated"
            if mutation == "no-evidence": check["evidence"] = []
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                verify_report(report, self.inputs, self.root)

    def test_stale_source_or_executable_blocks(self):
        for key in ["sourceInputSHA256", "testedExecutableSHA256"]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_report({**self.report, key: "changed"}, self.inputs, self.root)

    def test_tampered_or_missing_evidence_blocks(self):
        path = self.root / "ui-review.txt"
        path.write_text("changed")
        with self.assertRaises(ValueError): verify_report(self.report, self.inputs, self.root)
        path.unlink()
        with self.assertRaises(ValueError): verify_report(self.report, self.inputs, self.root)

    def test_wrong_runtime_and_incomplete_packaged_suite_block(self):
        report = copy.deepcopy(self.report)
        report["macOS26Environment"] = self.file("wrong-os.txt", b"ProductVersion: 27.0.1")
        with self.assertRaises(ValueError): verify_report(report, self.inputs, self.root)
        report = copy.deepcopy(self.report)
        report["packagedResults"] = self.file("failed.txt", b"PASS\nFAIL: incomplete")
        with self.assertRaises(ValueError): verify_report(report, self.inputs, self.root)

    def test_failed_wrong_or_stale_ci_blocks(self):
        for change in [{"conclusion": "failure"}, {"status": "in_progress"}, {"path": "other.yml"}, {"head_sha": "different"}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                verify_ci(self.report, {**self.run, **change}, self.inputs)
        with self.assertRaises(ValueError):
            verify_ci(self.report, self.run, {"sourceInputSHA256": "old"})

    def test_assets_must_match_draft_and_checksums(self):
        validation_path = self.root / "MacMermaid-v0.2.0-alpha-validation.zip"
        with zipfile.ZipFile(validation_path, "w") as archive:
            archive.writestr("validation-report.json", json.dumps(self.report))
            for name in ["ui-review.txt", "environment.txt", "results.txt"]:
                archive.write(self.root / name, name)
        validation = {"path": validation_path.name, "sha256": hashlib.sha256(validation_path.read_bytes()).hexdigest()}
        items = [self.report["appArchive"], validation]
        sums = self.file("SHA256SUMS", "".join(f'{item["sha256"]}  {item["path"]}\n' for item in items).encode())
        self.report["releaseAssets"] = [*items, sums]
        release = {"draft": True, "tag_name": "v0.2.0-alpha", "assets": [{"name": item["path"], "digest": f'sha256:{item["sha256"]}'} for item in self.report["releaseAssets"]]}
        verify_assets(self.root / "report.json", self.report, release)
        with self.assertRaises(ValueError): verify_assets(self.root / "report.json", self.report, {**release, "draft": False})
        release["assets"][0]["digest"] = "sha256:old"
        with self.assertRaises(ValueError): verify_assets(self.root / "report.json", self.report, release)


if __name__ == "__main__":
    unittest.main()
