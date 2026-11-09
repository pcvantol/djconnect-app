#!/usr/bin/env python3
"""Export the reviewed Core catalogue cases for Apple's offline HTTP fixture."""

import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess

from audit_core_catalog import CORE_INVENTORY_COMMIT, CORE_INVENTORY_SHA256
from golden import digest
from import_catalog import SOURCE


FAMILY = 'ASKDJ-FLOW-catalogue-exact-questions'
CATALOGUE = 'custom_components/djconnect/ask_dj/examples_v1.json'


def export(core_repo):
    def read(path):
        return subprocess.check_output([
            'git', '-C', str(core_repo), 'show', f'{CORE_INVENTORY_COMMIT}:{path}',
        ])

    matrix = read(SOURCE)
    if digest(matrix) != CORE_INVENTORY_SHA256:
        raise ValueError('core_inventory_digest_mismatch')
    catalogue = read(CATALOGUE)
    entries = {entry['id']: entry for entry in json.loads(catalogue)['entries']}
    family = next(f for f in json.loads(matrix)['families'] if f['id'] == FAMILY)
    rows, live_gates = [], []
    for step in family['steps']:
        if step.get('execution_profile') != 'catalogue_golden':
            live_gates.append(step['id'])
            continue
        row = {key: step[key] for key in ('id', 'entry_id', 'language', 'question')}
        if step['id'].startswith('catalogue-chain-'):
            row['chain'], row['operation'] = step['id'].rsplit('-', 1)
        else:
            row['active_session'] = entries[step['entry_id']]['contextual']
        rows.append(row)
    counts = Counter((row['language'], row.get('operation', 'question')) for row in rows)
    expected_counts = {
        (language, operation): count
        for language in ('en', 'nl', 'de', 'fr', 'es')
        for operation, count in (('question', 14), ('offer', 2), ('accept', 2), ('duplicate', 2))
    }
    if counts != expected_counts or len({row['id'] for row in rows}) != len(rows):
        raise ValueError('unexpected_catalogue_transport_inventory')
    if live_gates != [
        'ASKDJ-CATALOGUE-all-locales-actual-acceptance',
        'ASKDJ-CATALOGUE-generated-variants-actual-execution',
    ]:
        raise ValueError('unexpected_catalogue_live_gates')
    return {
        'core_commit': CORE_INVENTORY_COMMIT,
        'core_matrix_sha256': digest(matrix),
        'core_catalogue_sha256': digest(catalogue),
        'family_id': FAMILY,
        'rows': rows,
        'live_gate_ids': live_gates,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core-repo', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    data = export(args.core_repo)
    with args.output.open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
