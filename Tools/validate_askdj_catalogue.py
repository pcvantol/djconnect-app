#!/usr/bin/env python3
"""Source validation only: pin, shared reference fixtures, localizations, wiring.

Does not qualify producer routes, compile Swift, or exercise an installed app.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PIN = "dfaa98a1659ef5673037da26f98136314b314beea8afe8e31af4ffd5bd6ac4e7"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-root", type=Path)
    args = parser.parse_args()
    data = (ROOT / "Sources/DJConnectCore/Resources/ask_dj_examples_v1.json").read_bytes()
    assert hashlib.sha256(data).hexdigest() == PIN, "Catalogue bytes differ from reviewed pin"
    if args.core_root:
        assert data == (args.core_root / "custom_components/djconnect/ask_dj/examples_v1.json").read_bytes()
    catalogue = json.loads(data)
    assert catalogue["schema_version"] == catalogue["revision"] == 1
    assert catalogue["catalogue_id"] == "ask_dj_examples_v1"
    assert catalogue["selection"]["count"] == 3
    assert len({row["id"] for row in catalogue["entries"]}) == len(catalogue["entries"])
    swift = (ROOT / "Sources/DJConnectCore/DJConnectAskDJCatalogue.swift").read_text()
    assert PIN in swift
    assert 'status == "qualified_v1"' in swift
    assert '== "qualified_owner_route"' in swift
    assert 'e.publication == "qualified_v1"' in swift
    fixtures = json.loads((ROOT / "Tests/Fixtures/askdj-catalogue-selector-golden-v1.json").read_text())
    assert fixtures["source_sha256"] == PIN and "SYNTHETIC TEST ONLY" in fixtures["notice"]
    assert len(fixtures["cases"]) == 70
    for vector in fixtures["cases"]:
        rows = vector["expected"]
        assert len(rows) in (0, 3)
        assert len(set(row["intent"] for row in rows)) == len(rows)
        assert all(row["send"] == "existing_ask_dj_message_exact_prompt" for row in rows)
        assert all(not re.search(r"[{}\[\]]", row["prompt"]) for row in rows)
        assert len(vector["help"]) <= 3 and all(len(group[1]) <= 2 for group in vector["help"])
    ui = (ROOT / "Sources/DJConnectUI/DJConnectRootView.swift").read_text()
    session = (ROOT / "Sources/DJConnectUI/SessionTimelineScreen.swift").read_text()
    assert 'AskDJSuggestionStrip(model: model, surface: .askDJ' in ui
    assert 'AskDJSuggestionStrip(model: model, surface: .session' in session
    assert 'private var examples: [String]' not in ui[ui.index('private struct AskDJEmptyState:'):ui.index('private struct AskDJOfflineNotice:')]
    assert 'ui.session.suggestion.match_mood' not in session
    states = {}
    for entry in catalogue["entries"]:
        for language in catalogue["language_families"]:
            state = entry["qualification"][language]["state"]
            states[state] = states.get(state, 0) + 1
    print(json.dumps({"source_validation": "PASS", "sha256": PIN, "core_byte_equal": bool(args.core_root),
                      "catalogue_status": catalogue["status"], "locale_gates": states,
                      "synthetic_reference_vectors": len(fixtures["cases"]),
                      "swift_tests": "NOT_EXECUTED_BY_SOURCE_VALIDATOR", "native_acceptance": "NOT_EXECUTED_BY_SOURCE_VALIDATOR"}, indent=2))


if __name__ == "__main__":
    main()
