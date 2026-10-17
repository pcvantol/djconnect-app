#!/usr/bin/env python3
"""Validate the owning Apple work registers and render their Markdown projections."""
import argparse
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "docs/feedback"
STATES = {"CLOSED_BOUNDED", "SUPERSEDED", "PARTIAL", "BLOCKED", "OPEN", "PARKED"}


def cell(value):
    if isinstance(value, list):
        return "<br>".join(cell(item) for item in value)
    return str(value).replace("|", "\\|").replace("\n", "<br>")


def render(path):
    obj = json.loads(path.read_text())
    requirements = "requirements" in obj
    rows = obj["requirements" if requirements else "items"]
    assert rows and len({row["id"] for row in rows}) == len(rows), "Duplicate/empty work register"
    assert all(row["status"].upper() in STATES for row in rows), "Unknown status"
    assert all(row["evidence"] and row["remaining"] for row in rows), "Evidence/boundary required"
    if requirements:
        assert dict(sorted(Counter(row["status"] for row in rows).items())) == obj["counts"], "Counts drifted"
        lines = ["# Apple requirements: acceptatie en afsluiting — 17 oktober 2026", "",
                 "Owning register: [Apple #87](https://github.com/pcvantol/djconnect-app/issues/87). "
                 "CLOSED_BOUNDED sluit alleen de genoemde functionele implementatie of bewijslevering af. "
                 "Parentwerk, gereviewde bronoplevering en toestelacceptatie blijven afzonderlijke grenzen.", "",
                 "Actuele baseline: " + obj["baseline"], "", "Bron: " + obj["source_head"], "",
                 "; ".join(key + ": " + str(value) for key, value in obj["counts"].items()), "",
                 "| Requirement / herkomst | Status | Bewezen | Nog open / bewijsgrens |", "|---|---|---|---|"]
        for row in rows:
            origin = row["source"]
            name = ("[" + row["id"] + "](" + origin + ")") if origin.startswith("https://") else row["id"]
            lines.append("| " + " | ".join(cell(value) for value in [name + " — " + row["requirement"], row["status"], row["evidence"], row["remaining"]]) + " |")
    else:
        lines = ["# Integrale Apple-status en open werk", "",
                 "Actuele readback: " + obj["as_of"] + ". Owning register: [Apple #87](https://github.com/pcvantol/djconnect-app/issues/87). "
                 "Het [requirementregister](APPLE_REQUIREMENT_ACCEPTANCE_20261017.md) benoemt de afzonderlijke functionele afmeldingen. "
                 "Oudere receipts blijven bewijs voor hun eigen bron en build. Geen tweede writer.", "",
                 "Geïnstalleerd: " + obj["installed_baseline"], "",
                 "| Spoor | Status / eigenaar | Bewezen | Nog open |", "|---|---|---|---|"]
        for row in rows:
            lines.append("| " + " | ".join(cell(value) for value in [row["topic"], row["status"] + " / " + row["owner"], row["evidence"], row["remaining"]]) + " |")
    lines += ["", "Bewijs en uitvoering: [integrale uitvoering](APPLE_INTEGRAL_EXECUTION_20261017.md). "
              "De JSON-bron naast dit document is leidend; deze Markdown wordt met "
              "Tools/qualification/validate_apple_work_registers.py --write bijgewerkt.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    for name in ["APPLE_OPEN_WORK_20261017", "APPLE_REQUIREMENT_ACCEPTANCE_20261017"]:
        path = ROOT / (name + ".json")
        expected = render(path)
        markdown = path.with_suffix(".md")
        if args.write:
            markdown.write_text(expected)
        else:
            assert markdown.read_text() == expected, "Stale Markdown: " + str(markdown)
    print("PASS: Apple work register identities, counts, evidence boundaries and Markdown match")


if __name__ == "__main__":
    main()
