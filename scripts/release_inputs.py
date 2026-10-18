#!/usr/bin/env python3
"""Fingerprint committed build/test inputs so docs-only commits can share evidence."""
import argparse
import hashlib
import json
import subprocess


def git(*args):
    return subprocess.check_output(["git", *args])


def input_manifest(ref="HEAD"):
    names = git("ls-tree", "-r", "-z", "--name-only", ref).decode().split("\0")
    files = {}
    for name in sorted(names):
        if name in {"Package.swift", "Info.plist", "THIRD_PARTY_NOTICES.md"} or name.startswith(
            ("Sources/", "Tests/", "scripts/", "third-party/", ".github/")
        ):
            files[name] = hashlib.sha256(git("show", f"{ref}:{name}")).hexdigest()
    digest = hashlib.sha256("".join(f"{name}\0{sha}\n" for name, sha in files.items()).encode()).hexdigest()
    return {"commit": git("rev-parse", ref).decode().strip(), "sourceInputSHA256": digest, "files": files}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", default="HEAD")
    args = parser.parse_args()
    print(json.dumps(input_manifest(args.ref), indent=2))
