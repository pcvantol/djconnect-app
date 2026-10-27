#!/usr/bin/env python3
"""Compile/run only pure Swift byte and logical-model tests, outside the repo."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

source = Path(__file__).resolve().parent
repo = source.parents[2]
dest = Path(sys.argv[1]).resolve()
root = Path('/Volumes/Shared Data/tmp/pcvantol').resolve()
if not dest.is_relative_to(root) or dest == root or dest.exists():
    raise SystemExit('Use a new, nonexistent directory under Shared Data/tmp/pcvantol')
manifest = json.loads((source / 'fixtures/manifest.json').read_bytes())
for name, expected in manifest['fixture_sha256'].items():
    assert hashlib.sha256((source / 'fixtures' / name).read_bytes()).hexdigest() == expected, name
lexical = repo / manifest['strict_lexical_source']
assert hashlib.sha256(lexical.read_bytes()).hexdigest() == manifest['strict_lexical_sha256']
inputs = [source / 'PreparedPushProof.swift', source / 'main.swift', source / 'run_preflight.py', lexical, *sorted((source / 'fixtures').glob('*.json'))]
def hashes():
    return {str(p.relative_to(repo)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
before = hashes()
dest.mkdir(parents=True)
(dest / 'inputs-before.json').write_text(json.dumps(before, indent=2)+'\n')
(dest / 'lexical.swift').write_bytes(lexical.read_bytes())
(dest / 'error.swift').write_text('enum DJConnectError: Error { case invalidResponse }\n')
cases = []
for x in json.loads((source / 'fixtures/canonical-transcript-vectors.json').read_bytes())['cases']:
    cases.append(dict(case_id=x['proof_variant']+'/widget-control', transcript=x['transcript'], byte_control=x))
for name in ['negative-shape-and-context-vectors.json', 'causal-activity-shape-expectations.json']:
    for x in json.loads((source / 'fixtures' / name).read_bytes())['cases']:
        cases.append(dict(case_id=x['case_id'], transcript=x['transcript']))
assert len(cases) == 32
(dest / 'cases.json').write_text(json.dumps(cases, ensure_ascii=False, indent=2)+'\n')
env = dict(os.environ, TMPDIR=str(dest))
compiler = subprocess.check_output(['xcrun', '--find', 'swiftc'], text=True).strip()
version = subprocess.check_output([compiler, '--version'], text=True, stderr=subprocess.STDOUT)
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
command = [compiler, '-sdk', sdk, '-swift-version', '6', '-module-cache-path', str(dest / 'module-cache'), str(dest / 'error.swift'), str(dest / 'lexical.swift'), str(source / 'PreparedPushProof.swift'), str(source / 'main.swift'), '-o', str(dest / 'probe')]
with (dest / 'compile.log').open('wb') as log:
    compiled = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, check=False)
(dest / 'compile.exit').write_text(str(compiled.returncode)+'\n')
run_code = None
if compiled.returncode == 0:
    with (dest / 'run.log').open('wb') as log:
        run = subprocess.run([str(dest / 'probe'), str(dest / 'cases.json')], env=env, stdout=log, stderr=subprocess.STDOUT, check=False)
    run_code = run.returncode
    (dest / 'run.exit').write_text(str(run_code)+'\n')
after = hashes()
(dest / 'inputs-after.json').write_text(json.dumps(after, indent=2)+'\n')
text = (dest / 'run.log').read_text() if run_code is not None else ''
result = re.search(r'^RESULT (\d+) PASS / (\d+) FAIL;', text, re.MULTILINE)
receipt = dict(scope='Uncomposed pure parser and synthetic logical model only; no native/provider/admission acceptance', toolchain=version.strip(), compiler_command=command, compile_parent_exit=compiled.returncode, run_parent_exit=run_code, all_inputs_unchanged=before == after, outcomes=dict(passed=int(result[1]), failed=int(result[2])) if result else None, logs_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in dest.glob('*.log')}, protocol_pins=manifest)
(dest / 'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps(receipt['outcomes']))
if before != after or compiled.returncode != 0 or run_code != 0 or not result or int(result[2]) != 0:
    raise SystemExit(f'Qualification failed; original evidence retained at {dest}')
