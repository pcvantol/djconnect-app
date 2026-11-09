#!/usr/bin/env python3
"""Run the Core tests named by the Golden delta in a disposable source snapshot."""

import argparse
import json
import os
from pathlib import Path

import pytest

from audit_core_catalog import CORE_INVENTORY_SHA256, execution_plan
from golden import catalog, digest
from import_catalog import SOURCE


def run(snapshot, output):
    inventory = (snapshot / SOURCE).read_bytes()
    if digest(inventory) != CORE_INVENTORY_SHA256:
        raise ValueError('core_inventory_digest_mismatch')
    families = execution_plan(catalog(), json.loads(inventory))
    references = {
        (test['file'], test['method'])
        for family in families for case in family['cases']
        for test in case['core']['owning_tests']
    }
    selected = {}
    passed = set()
    unsuccessful = set()

    class Selection:
        def pytest_collection_modifyitems(self, config, items):
            accepted, rejected = [], []
            for item in items:
                ref = item.path.relative_to(config.rootpath).as_posix(), item.originalname or item.name
                if ref in references:
                    selected.setdefault(ref, []).append(item.nodeid)
                    accepted.append(item)
                else:
                    rejected.append(item)
            config.hook.pytest_deselected(items=rejected)
            items[:] = accepted

        def pytest_runtest_logreport(self, report):
            if report.outcome != 'passed':
                unsuccessful.add(report.nodeid)
            elif report.when == 'call':
                passed.add(report.nodeid)

    output.mkdir()
    os.chdir(snapshot)
    result = pytest.main([
        '-q', '-p', 'no:cacheprovider', '--junitxml', str(output / 'pytest.xml'),
        *sorted({file for file, _ in references}),
    ], plugins=[Selection()])
    cases = []
    for family in families:
        for case in family['cases']:
            step = case['core']
            refs = [(test['file'], test['method']) for test in step['owning_tests']]
            green = bool(refs) and all(
                selected.get(ref) and all(node in passed and node not in unsuccessful for node in selected[ref])
                for ref in refs
            )
            cases.append({
                'id': step['id'],
                'core_fixture_status': 'PASS' if green else 'NOT_PASSED',
                'live_quality_required': step['acceptance_status'] == 'open_real_quality',
            })
    missing = sorted(references - selected.keys())
    (output / 'summary.json').write_text(json.dumps({
        'core_matrix_sha256': CORE_INVENTORY_SHA256,
        'selected_tests': sum(map(len, selected.values())),
        'missing_tests': missing,
        'cases': cases,
    }, indent=2) + '\n')
    return int(bool(result or missing or any(row['core_fixture_status'] != 'PASS' for row in cases)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core-snapshot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run(args.core_snapshot.resolve(), args.output.resolve()))
