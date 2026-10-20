#!/usr/bin/env python3
"""Opt-in Apple Ask DJ Golden planning and release-evidence reconciliation.

This is test orchestration, not a production API or a provider-receipt exporter.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import uuid

HERE = Path(__file__).resolve().parent
CATALOG_SHA = 'f54eaffb4d3caa7760a2462e6e4f50943b670409581cbdc04a58c70b00dd1359'
CORE_COMMIT = '8b221d07fe2215d9516d18fe92c832332c7a16ab'


def valid_digest(value, length=64):
    return isinstance(value, str) and len(value) == length and all(c in "0123456789abcdef" for c in value)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def catalog():
    raw = (HERE / 'core-catalog.json').read_bytes()
    if digest(raw) != CATALOG_SHA:
        raise ValueError('catalog_digest_mismatch')
    return json.loads(raw)


def private_read(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_mode & 0o077:
        raise ValueError('private_regular_0600_file_required')
    if path.stat().st_size > 2_000_000:
        raise ValueError('input_too_large')
    return json.loads(path.read_bytes())


def private_write(path, value):
    path = Path(path)
    # Exclusive creation: existing receipts/plans and their run identities survive.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def plan(context, families):
    data = catalog()
    by_id = {f['id']: f for f in data['families']}
    if not families or len(set(families)) != len(families) or any(f not in by_id for f in families):
        raise ValueError('unknown_or_duplicate_family')
    steps = [dict(s, family=f) for f in families for s in by_id[f]['steps']]
    if not 1 <= len(steps) <= context['request_limit'] <= 40:
        raise ValueError('request_budget')
    if not 1 <= context['model_attempts_per_turn'] <= 2:
        raise ValueError('published_core_attempt_ceiling_required')
    reserve = sum(0 if step.get('model_policy') == 'zero' else context['model_attempts_per_turn'] for step in steps)
    if not 1 <= context['max_model_calls'] <= 40 or reserve > context['max_model_calls']:
        raise ValueError('worst_case_model_budget')
    if context.get('fixture_admission') != 'QUALIFIED_DISPOSABLE_SESSION':
        raise ValueError('core_fixture_admission_required')
    for key in ('profile_sha256', 'session_sha256', 'app_executable_sha256', 'core_install_receipt_sha256'):
        if len(context.get(key, '')) != 64 or any(c not in '0123456789abcdef' for c in context[key]):
            raise ValueError('missing_identity_or_install_pin')
    if context.get('bundle_id') not in ('dev.djconnect.mac', 'dev.djconnect.ios') or not context.get('app_build'):
        raise ValueError('ordinary_app_identity_required')
    if context.get('language') not in ('en', 'nl', 'de', 'fr', 'es'):
        raise ValueError('language_required')
    # Existing source questions retain their exact language. Do not claim five
    # locale execution by attaching a language field to Dutch Golden questions.
    if context['language'] != 'nl':
        raise ValueError('localized_core_consumer_export_pending')
    result = dict(context, schema_version=1, run_id=str(uuid.uuid4()), core_commit=CORE_COMMIT,
                  catalog_sha256=CATALOG_SHA, steps=steps, timeout_seconds=120, wall_seconds=600)
    result['execute'] = False
    result['scope'] = 'native_model_send_path; ui_gestures_and_hardware_separate'
    return result


def reconcile(native, producer, expected_producer_sha):
    """Join private Core/provider evidence; invocation counts alone never pass.

    Producer adapter schema is a handoff proposal until Core publishes/qualifies
    its exporter. Caller supplies the independently reviewed producer commit.
    """
    failures = []
    if not valid_digest(expected_producer_sha, 40) or producer.get('producer_commit') != expected_producer_sha:
        failures.append('producer_pin')
    for key in ('run_id', 'catalog_sha256', 'session_sha256', 'profile_sha256', 'app_executable_sha256', 'core_install_receipt_sha256'):
        if not native.get(key) or native.get(key) != producer.get(key):
            failures.append('binding_' + key)
    if native.get('catalog_sha256') != CATALOG_SHA or producer.get('export_status') != 'QUALIFIED':
        failures.append('unqualified_catalog_or_export')
    if native.get('status') != 'CLIENT_EXERCISED_NOT_RELEASE_PASS':
        failures.append('native_run_not_completed')
    known = {s['id']: s for f in catalog()['families'] for s in f['steps']}
    if any(case_id not in known for case_id in native.get('expected_case_ids', [])):
        failures.append('unknown_core_scenario')
    cases = native.get('cases', [])
    expected = native.get('expected_case_ids', [])
    if not expected or len(set(expected)) != len(expected) or [c.get('id') for c in cases] != expected:
        failures.append('native_coverage')
    rows = producer.get('cases', [])
    if [c.get('id') for c in rows] != expected:
        failures.append('producer_coverage')
    total = 0
    attempt_ids = set()
    for case, row in zip(cases, rows):
        original = known.get(case.get('id'), {})
        if case.get('question_sha256') != digest(original.get('question', '').encode()):
            failures.append('canonical_question_mismatch')
        if case.get('model_policy') != original.get('model_policy'):
            failures.append('canonical_model_policy_mismatch')
        if case.get('status') != 'CLIENT_ACCEPTED_PROVIDER_UNVERIFIED' or case.get('native_bubble_rendered') is not True:
            failures.append('native_failure')
        for key in ('client_message_sha256', 'server_turn_sha256', 'answer_sha256', 'question_sha256', 'session_entry_sha256'):
            if not valid_digest(case.get(key)) or case.get(key) != row.get(key):
                failures.append('turn_binding_' + key)
        if row.get('semantic_verdict') != 'PASS' or row.get('effects_verdict') != 'PASS':
            failures.append('core_semantic_or_effect_failure')
        attempts = row.get('provider_attempts', [])
        policy = case.get('model_policy')
        if policy == 'zero' and attempts:
            failures.append('unexpected_model_use')
        if policy == 'one_or_two' and not 1 <= len(attempts) <= 2:
            failures.append('required_model_missing')
        if len(attempts) > native.get('model_attempts_per_turn', 0):
            failures.append('per_turn_model_budget')
        for attempt in attempts:
            # Includes failed attempts in the budget; no successful retry hiding.
            total += 1
            aid = attempt.get('provider_receipt_sha256')
            if not valid_digest(aid) or aid in attempt_ids:
                failures.append('missing_or_reused_provider_receipt')
            attempt_ids.add(aid)
            if attempt.get('attempted') is not True or attempt.get('completed') is not True or not attempt.get('model'):
                failures.append('provider_not_completed')
            if type(attempt.get('output_tokens')) is not int or attempt['output_tokens'] <= 0:
                failures.append('provider_usage_missing')
    if producer.get('unattributed_provider_attempts') != 0 or producer.get('observed_total_provider_attempts') != total:
        failures.append('unbound_or_unreported_model_usage')
    if type(native.get('max_model_calls')) is not int or not 1 <= native['max_model_calls'] <= 40 or not 0 <= total <= native['max_model_calls']:
        failures.append('overall_model_budget')
    # No native diagnostic-only report is a production release approval.
    return {'schema_version': 1, 'status': 'FAIL' if failures else 'PASS_SELECTED_SET',
            'catalog_sha256': native.get('catalog_sha256'),
            'app_executable_sha256': native.get('app_executable_sha256'),
            'core_install_receipt_sha256': native.get('core_install_receipt_sha256'),
            'producer_commit': expected_producer_sha,
            'passed_case_ids': [] if failures else expected,
            'findings': sorted(set(failures)), 'cases': len(cases), 'paid_attempts': total,
            'native_ui_gestures': 'NOT_RUN', 'physical_audio': 'NOT_RUN',
            'release_authorization': 'NOT_GRANTED'}


def release_gate(receipts):
    required = {s['id'] for f in catalog()['families'] for s in f['steps']}
    seen = []
    bindings = set()
    failures = []
    for receipt in receipts:
        if receipt.get('status') != 'PASS_SELECTED_SET':
            failures.append('failed_or_unverified_batch')
        if receipt.get('catalog_sha256') != CATALOG_SHA:
            failures.append('catalog_version_mismatch')
        if any(not valid_digest(receipt.get(k)) for k in ('app_executable_sha256', 'core_install_receipt_sha256')) or not valid_digest(receipt.get('producer_commit'), 40):
            failures.append('invalid_candidate_pin')
        if type(receipt.get('paid_attempts')) is not int or receipt['paid_attempts'] < 0:
            failures.append('invalid_model_usage')
        bindings.add(tuple(receipt.get(k) for k in ('catalog_sha256', 'app_executable_sha256', 'core_install_receipt_sha256', 'producer_commit')))
        seen.extend(receipt.get('passed_case_ids', []))
    if len(bindings) != 1 or any(not v for binding in bindings for v in binding):
        failures.append('mixed_or_missing_candidate_bindings')
    if len(set(seen)) != len(seen):
        failures.append('duplicate_case_coverage')
    if sum(r.get('paid_attempts', 0) for r in receipts if type(r.get('paid_attempts')) is int) <= 0:
        failures.append('no_real_model_calls')
    if set(seen) != required:
        failures.append('incomplete_core_matrix')
    return {'schema_version': 1, 'status': 'FAIL' if failures else 'PASS_CORE_CLIENT_GOLDEN',
            'findings': failures, 'covered': len(set(seen) & required), 'required': len(required),
            'missing_case_ids': sorted(required - set(seen)), 'native_ui_gestures': 'NOT_RUN',
            'physical_audio': 'NOT_RUN', 'release_authorization': 'NOT_GRANTED'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('inventory')
    make = sub.add_parser('plan')
    make.add_argument('--context', required=True)
    make.add_argument('--family', action='append', required=True)
    make.add_argument('--output', required=True)
    check = sub.add_parser('reconcile')
    check.add_argument('--native', required=True)
    check.add_argument('--producer', required=True)
    check.add_argument('--producer-commit', required=True)
    check.add_argument('--output', required=True)
    gate = sub.add_parser('release-gate')
    gate.add_argument('--receipt', action='append', required=True)
    gate.add_argument('--output', required=True)
    args = parser.parse_args()
    if args.command == 'inventory':
        data = catalog()
        for family in data['families']:
            print(family['id'], len(family['steps']))
    elif args.command == 'plan':
        private_write(args.output, plan(private_read(args.context), args.family))
        print('PLAN_CREATED_NOT_ARMED; inspect private plan and fixture preconditions before execute=true')
    elif args.command == 'reconcile':
        result = reconcile(private_read(args.native), private_read(args.producer), args.producer_commit)
        private_write(args.output, result)
        print(result['status'])
        return int(result['status'] != 'PASS_SELECTED_SET')
    else:
        result = release_gate([private_read(p) for p in args.receipt])
        private_write(args.output, result)
        print(result['status'])
        return int(result['status'] != 'PASS_CORE_CLIENT_GOLDEN')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError):
        # Never print an exception containing paths/private JSON/provider text.
        raise SystemExit('FAIL: invalid input or missing qualified evidence')
