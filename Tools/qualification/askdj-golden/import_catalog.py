#!/usr/bin/env python3
"""Reproduce the reviewed catalogue from immutable Core Git objects; no network."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

PIN = '8b221d07fe2215d9516d18fe92c832332c7a16ab'
SOURCE = 'docs/verification/fixtures/askdj_golden_release_matrix_v1.json'


def derive(raw):
    matrix = json.loads(raw)
    return {'schema_version': 1, 'core_commit': PIN, 'source_path': SOURCE,
            'source_sha256': hashlib.sha256(raw).hexdigest(),
            'families': [{'id': f['id'], 'steps': [
                {k: s[k] for k in ('id', 'question', 'model_policy', 'expected_answer', 'owning_tests') if k in s}
                for s in f['steps']]} for f in matrix['families']]}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core-repo', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raw = subprocess.check_output(['git', '-C', str(args.core_repo), 'show', f'{PIN}:{SOURCE}'])
    # Never overwrite an admitted catalogue from a new/uncertain checkout.
    with args.output.open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(derive(raw), ensure_ascii=False, indent=2) + '\n')
