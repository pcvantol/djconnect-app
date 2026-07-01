#!/usr/bin/env python3
"""Validate DJConnect Apple client localization coverage.

The shared Apple client localization files must contain the same keys for every
supported language, and each translated value must keep the same printf
placeholders as English.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


SUPPORTED_LOCALES = ("en", "nl", "de", "fr", "es")
ROOT = Path(__file__).resolve().parents[1]
LOCALIZATION_ROOT = ROOT / "Resources" / "Localization"
STRING_RE = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";\s*$')
PLACEHOLDER_RE = re.compile(r"%(?:[0-9]+\$)?(?:[-+ #0])?(?:[0-9]+)?(?:\.[0-9]+)?[@dfius]")


def parse_strings(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        match = STRING_RE.match(line)
        if not match:
            raise ValueError(f"{path}:{line_number}: invalid .strings line")
        key, value = match.groups()
        if key in values:
            raise ValueError(f"{path}:{line_number}: duplicate key {key!r}")
        values[key] = value
    return values


def placeholders(value: str) -> list[str]:
    return PLACEHOLDER_RE.findall(value)


def main() -> int:
    catalogs: dict[str, dict[str, str]] = {}
    errors: list[str] = []

    for locale in SUPPORTED_LOCALES:
        path = LOCALIZATION_ROOT / f"{locale}.lproj" / "Localizable.strings"
        if not path.exists():
            errors.append(f"Missing localization file: {path.relative_to(ROOT)}")
            continue
        try:
            catalogs[locale] = parse_strings(path)
        except ValueError as exc:
            errors.append(str(exc))

    if "en" in catalogs:
        english_keys = set(catalogs["en"])
        for locale, catalog in catalogs.items():
            missing = sorted(english_keys - set(catalog))
            extra = sorted(set(catalog) - english_keys)
            errors.extend(f"{locale}: missing key {key!r}" for key in missing)
            errors.extend(f"{locale}: extra key {key!r}" for key in extra)

        for key, english_value in catalogs["en"].items():
            expected = placeholders(english_value)
            for locale, catalog in catalogs.items():
                actual = placeholders(catalog.get(key, ""))
                if actual != expected:
                    errors.append(
                        f"{locale}: placeholders for {key!r} are {actual}, expected {expected}"
                    )

    if errors:
        print("Localization validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Localization validation passed for {len(catalogs.get('en', {}))} keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
