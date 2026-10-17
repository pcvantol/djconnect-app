#!/usr/bin/env python3
"""Produce lexical Swift orphan candidates; never infer runtime reachability or delete code.

Includes comments/strings in counts (conservative overcount). Protocol callbacks,
@main, previews, public API consumers and transitive reachability need human review.
--check verifies that a saved assessment still describes the same source snapshot.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
TOKEN = re.compile(r"\b[A-Za-z_][A-Za-z_0-9]*\b")
DECLARATION = re.compile(
    r"(?m)^[ \t]*(?:(public|private|fileprivate|internal|package|open)[ \t]+)?"
    r"(?:(?:static|final|override|mutating|nonmutating|nonisolated|indirect|"
    r"convenience|required|distributed)[ \t]+)*"
    r"(func|struct|enum|class|actor|protocol)[ \t]+([A-Za-z_][A-Za-z_0-9]*)"
)


def collect():
    paths = sorted(p for directory in ("Sources", "Apps")
                   for p in (ROOT / directory).rglob("*.swift"))
    contents = {p: p.read_text() for p in paths}
    production = Counter(token for content in contents.values() for token in TOKEN.findall(content))
    test_tokens = Counter(token for p in sorted((ROOT / "Tests").rglob("*.swift"))
                          for token in TOKEN.findall(p.read_text()))
    qualification_tokens = Counter(token for p in sorted((ROOT / "Tools/qualification").rglob("*.swift"))
                                   for token in TOKEN.findall(p.read_text()))
    candidates = []
    for path, content in contents.items():
        for match in DECLARATION.finditer(content):
            access, kind, name = match.groups()
            if production[name] != 1:
                continue
            candidates.append(dict(file=str(path.relative_to(ROOT)), line=content.count("\n", 0, match.start()) + 1,
                                   access=access or "internal", kind=kind, name=name,
                                   production_token_occurrences=production[name],
                                   test_token_occurrences=test_tokens[name],
                                   qualification_token_occurrences=qualification_tokens[name]))
    return dict(schema_version=1, method="lexical_candidates_not_semantic_dead_code_proof",
                source_file_count=len(paths),
                source_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
                candidate_count=len(candidates), candidates=candidates)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check", type=Path, help="Verify saved source hashes and candidate inventory; no rewriting")
    args = parser.parse_args()
    if args.output and args.check:
        parser.error("Choose --output or --check")
    result = collect()
    if args.check:
        baseline = json.loads(args.check.read_text())
        if result != baseline:
            raise SystemExit("STALE: source/candidates changed; reassess before using the saved inventory")
        print(f"PASS: {result['source_file_count']} source hashes and {result['candidate_count']} lexical candidates match; no runtime claim")
    elif args.output:
        args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
        print(f"Wrote {result['candidate_count']} candidates from {result['source_file_count']} Swift source files")
    else:
        print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
