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
LOCALIZATION_ROOT = ROOT / "Sources" / "DJConnectCore" / "Resources" / "Localization"
INFO_PLIST_LOCALIZATION_ROOTS = (
    ROOT / "Apps" / "DJConnectIOS",
    ROOT / "Apps" / "DJConnectMac",
    ROOT / "Apps" / "DJConnectWatch",
    ROOT / "Apps" / "DJConnectTrackInsightWidgets",
    ROOT / "Apps" / "DJConnectWatchComplications",
)
STRING_RE = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";\s*$')
PLACEHOLDER_RE = re.compile(r"%(?:[0-9]+\$)?(?:[-+ #0])?(?:[0-9]+)?(?:\.[0-9]+)?[@dfius]")
INLINE_PAIR_PATTERNS = (
    re.compile(r'localized\(english:\s*"'),
    re.compile(r'DJConnectLocalization\.localized\([^)\n]*(?:english:\s*"|dutch:\s*")'),
    re.compile(r'DJConnectLocalization\.localized\([^)\n]*fallback\s*:'),
    re.compile(r'\b(?:localizedKey|watchLocalizedKey|localized)\([^)\n]*fallback\s*:'),
    re.compile(r'watchLocalized\([^)\n]*,\s*"[^"]*"\s*,\s*"[^"]*"'),
    re.compile(r'localized\([^)\n]*,\s*"[^"]*"\s*,\s*"[^"]*"'),
    re.compile(r'func\s+\w*localized\([^)]*dutch\s*:'),
    re.compile(r'localized\(language:\s*[^,\n]+,\s*english:'),
    re.compile(r'localized\(locale:\s*[^,\n]+,\s*english:'),
)
INLINE_PAIR_EXCLUDED_FILES = {
}
INLINE_PAIR_EXCLUDED_SNIPPETS = (
)


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


def validate_no_inline_ui_pairs() -> list[str]:
    violations: list[str] = []
    whole_file_patterns = (
        re.compile(r'localized\(\s*(?:[^,\n]+,\s*)?"(?:\\.|[^"\\])*"\s*,\s*"(?:\\.|[^"\\])*"', re.DOTALL),
        re.compile(r'watchLocalized\(\s*(?:[^,\n]+,\s*)?"(?:\\.|[^"\\])*"\s*,\s*"(?:\\.|[^"\\])*"', re.DOTALL),
        re.compile(r'func\s+\w+\([^)]*\benglish\s*:[^)]*\bdutch\s*:', re.DOTALL),
        re.compile(r'func\s+\w+\([^)]*\bdutch\s*:[^)]*\benglish\s*:', re.DOTALL),
        re.compile(r'func\s+\w*localized\([^)]*dutch\s*:', re.DOTALL),
        re.compile(r'DJConnectLocalization\.localized\([^)]*(?:english\s*:|dutch\s*:)', re.DOTALL),
        re.compile(r'DJConnectLocalization\.localized\([^)]*fallback\s*:', re.DOTALL),
        re.compile(r'\b(?:localizedKey|watchLocalizedKey|localized)\([^)]*fallback\s*:', re.DOTALL),
    )
    for base in (ROOT / "Sources", ROOT / "Apps"):
        for path in base.rglob("*.swift"):
            if path in INLINE_PAIR_EXCLUDED_FILES:
                continue
            text = path.read_text(encoding="utf-8")
            for pattern in whole_file_patterns:
                match = pattern.search(text)
                if match:
                    line_number = text.count("\n", 0, match.start()) + 1
                    violations.append(
                        f"{path.relative_to(ROOT)}:{line_number}: use a semantic Localizable.strings key"
                    )
                    break
            for line_number, line in enumerate(text.splitlines(), 1):
                if any(snippet in line for snippet in INLINE_PAIR_EXCLUDED_SNIPPETS):
                    continue
                if any(pattern.search(line) for pattern in INLINE_PAIR_PATTERNS):
                    violations.append(
                        f"{path.relative_to(ROOT)}:{line_number}: use a semantic Localizable.strings key"
                    )
    return violations


def validate_locale_set(
    root: Path,
    filename: str,
    *,
    require_placeholders: bool = True,
) -> tuple[int, list[str]]:
    catalogs: dict[str, dict[str, str]] = {}
    errors: list[str] = []

    for locale in SUPPORTED_LOCALES:
        path = root / f"{locale}.lproj" / filename
        if not path.exists():
            errors.append(f"Missing localization file: {path.relative_to(ROOT)}")
            continue
        try:
            catalogs[locale] = parse_strings(path)
        except ValueError as exc:
            errors.append(str(exc))

    if "en" not in catalogs:
        return 0, errors

    for locale, catalog in catalogs.items():
        for key, value in catalog.items():
            if r"\(" in value:
                errors.append(
                    f"{root.relative_to(ROOT)} {locale}: {key!r} contains Swift interpolation syntax"
                )

    english_keys = set(catalogs["en"])
    for locale, catalog in catalogs.items():
        missing = sorted(english_keys - set(catalog))
        extra = sorted(set(catalog) - english_keys)
        errors.extend(
            f"{root.relative_to(ROOT)} {locale}: missing key {key!r}" for key in missing
        )
        errors.extend(
            f"{root.relative_to(ROOT)} {locale}: extra key {key!r}" for key in extra
        )

    if require_placeholders:
        for key, english_value in catalogs["en"].items():
            expected = placeholders(english_value)
            for locale, catalog in catalogs.items():
                actual = placeholders(catalog.get(key, ""))
                if actual != expected:
                    errors.append(
                        f"{root.relative_to(ROOT)} {locale}: placeholders for {key!r} are {actual}, expected {expected}"
                    )

    return len(catalogs["en"]), errors


def main() -> int:
    errors: list[str] = []
    localizable_count, localizable_errors = validate_locale_set(
        LOCALIZATION_ROOT,
        "Localizable.strings",
    )
    errors.extend(localizable_errors)

    for root in INFO_PLIST_LOCALIZATION_ROOTS:
        _, info_plist_errors = validate_locale_set(root, "InfoPlist.strings")
        errors.extend(info_plist_errors)

    errors.extend(validate_no_inline_ui_pairs())

    if errors:
        print("Localization validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Localization validation passed for {localizable_count} keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
