#!/usr/bin/env python3
"""Compare the Apple hosted adapter with a reviewed Core inventory, offline."""

import argparse
import json
from pathlib import Path
import subprocess

import golden
from import_catalog import SOURCE


CORE_INVENTORY_COMMIT = '7d6e5c07500ba281a2152c270ea5a8b2814a16c2'
CORE_INVENTORY_SHA256 = '0f21f97b8931580460113ba152dc60b3b020b765b0f52f8a5d4b3d57468ba046'
PROJECTED_FIELDS = ('question', 'model_policy', 'expected_answer', 'owning_tests')


def families_by_id(document):
    families = document['families']
    by_id = {family['id']: family['steps'] for family in families}
    steps = [step['id'] for family in families for step in family['steps']]
    if len(by_id) != len(families) or len(set(steps)) != len(steps):
        raise ValueError('duplicate_family_or_case')
    return by_id


def audit(apple, core):
    apple_families = families_by_id(apple)
    core_families = families_by_id(core)
    findings = {}
    for family_id, core_steps in core_families.items():
        apple_steps = apple_families.get(family_id, [])
        apple_by_id = {step['id']: step for step in apple_steps}
        issues = {}
        if [step['id'] for step in apple_steps] != [step['id'] for step in core_steps]:
            issues['chain_mismatch'] = True
        for step in core_steps:
            case_id = step['id']
            previous = apple_by_id.get(case_id)
            if previous is None:
                issues.setdefault('missing_cases', []).append(case_id)
            elif any(previous.get(field) != step.get(field) for field in PROJECTED_FIELDS):
                issues.setdefault('changed_cases', []).append(case_id)
            if step.get('model_policy') not in golden.MODEL_POLICY_RANGES:
                issues.setdefault('unsupported_model_policy', []).append(case_id)
            if step.get('language', 'nl') != 'nl':
                issues.setdefault('unsupported_language', []).append(case_id)
            # The hosted adapter only drives the ordinary text composer.
            if 'input_kind' in step or 'execution_profile' in step:
                issues.setdefault('requires_route_review', []).append(case_id)
        if issues:
            findings[family_id] = issues
    for family_id in apple_families.keys() - core_families.keys():
        findings[family_id] = {'absent_from_core': True}
    return {
        'status': 'GAPS_FOUND' if findings else 'NO_STATIC_GAPS_FOUND',
        'apple_families': len(apple_families),
        'apple_steps': sum(map(len, apple_families.values())),
        'core_families': len(core_families),
        'core_steps': sum(map(len, core_families.values())),
        'findings': findings,
    }


def execution_plan(apple, core):
    """Preserve changed expectations and complete chains for adapter work."""
    findings = audit(apple, core)['findings']
    previous = families_by_id(apple)
    result = []
    for family_id, steps in families_by_id(core).items():
        issues = findings.get(family_id, {})
        missing = set(issues.get('missing_cases', []))
        changed = set(issues.get('changed_cases', []))
        if not missing and not changed and not issues.get('chain_mismatch'):
            continue
        old_steps = {step['id']: step for step in previous.get(family_id, [])}
        result.append({
            'id': family_id,
            'previous_order': list(old_steps),
            'core_order': [step['id'] for step in steps],
            'cases': [
                {
                    'change': 'missing' if step['id'] in missing else 'changed',
                    'core': step,
                    'previous': old_steps.get(step['id']),
                }
                for step in steps if step['id'] in missing or step['id'] in changed
            ],
        })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core-repo', type=Path, required=True)
    parser.add_argument('--core-ref', default='origin/main', help='Local Core ref to check for inventory drift')
    parser.add_argument('--execution-plan', action='store_true',
                        help='Include canonical steps and the previous and current chain order')
    args = parser.parse_args()
    command = ['git', '-C', str(args.core_repo), 'show', '--end-of-options']
    raw = subprocess.check_output([*command, f'{CORE_INVENTORY_COMMIT}:{SOURCE}'])
    if golden.digest(raw) != CORE_INVENTORY_SHA256:
        raise SystemExit('Core inventory digest mismatch')
    current = subprocess.check_output([*command, f'{args.core_ref}:{SOURCE}'])
    if golden.digest(current) != CORE_INVENTORY_SHA256:
        raise SystemExit('Core inventory changed; review it before updating the audit pin')
    apple, core = golden.catalog(), json.loads(raw)
    report = audit(apple, core)
    if args.execution_plan:
        report['execution_plan'] = execution_plan(apple, core)
    report['core_inventory_commit'] = CORE_INVENTORY_COMMIT
    print(json.dumps(report, indent=2, sort_keys=True))
    return int(bool(report['findings']))


if __name__ == '__main__':
    raise SystemExit(main())
