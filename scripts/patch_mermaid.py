#!/usr/bin/env python3
"""Apply or verify the narrow, reversible patch to the pinned Mermaid bundle."""
import argparse
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM_SHA256 = "a8a6a6f805b074a8261a2825c86f99c8054acb3b35f50bb7e24a4f9f2c3c3b9f"
BUNDLE = ROOT / "Sources/MacMermaid/Resources/Web/mermaid.min.js"
PATCH = ROOT / "third-party/patches/swimlane-space.js"
HEADER = "/* Mermaid 12.2.0 with MacMermaid lane-spacing patch. See third-party/patches/README.md. */\n"
MEASURE_OLD = 'let S=a.unwrapGroupLabels&&E.labelType!=="markdown";'
MEASURE_NEW = 'let S=(a.unwrapGroupLabels||r.layoutAlgorithm==="swimlane")&&E.labelType!=="markdown";'
CORE_OLD = 'function VEr(t){'


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise ValueError("Pinned Mermaid patch anchor is missing or ambiguous")
    return text.replace(before, after, 1)


def core_replacement():
    return PATCH.read_text() + '\nfunction VEr(t){return macMermaidSwimlaneCore(t,macMermaidOriginalSwimlaneCore)}function macMermaidOriginalSwimlaneCore(t){'


def patch(original):
    if hashlib.sha256(original).hexdigest() != UPSTREAM_SHA256:
        raise ValueError("Input is not the audited, unmodified Mermaid 12.2.0 bundle")
    text = replace_once(original.decode(), MEASURE_OLD, MEASURE_NEW)
    return (HEADER + replace_once(text, CORE_OLD, core_replacement())).encode()


def verify(patched):
    text = patched.decode()
    if not text.startswith(HEADER):
        raise ValueError("Missing Mermaid patch provenance")
    text = replace_once(text[len(HEADER):], core_replacement(), CORE_OLD)
    original = replace_once(text, MEASURE_NEW, MEASURE_OLD).encode()
    if patch(original) != patched:
        raise ValueError("Patched Mermaid does not reproduce from the audited upstream bundle")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="Original npm mermaid.min.js; omit to verify the committed patched bundle")
    parser.add_argument("--output", type=Path, default=BUNDLE)
    args = parser.parse_args()
    if args.input:
        args.output.write_bytes(patch(args.input.read_bytes()))
    verify(args.output.read_bytes())
    print("Mermaid lane-spacing patch reproduces from the audited upstream checksum.")
