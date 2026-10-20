"""Pure orchestration regressions; synthetic data is NOT live provider evidence."""
import copy
import unittest
import golden
import run_hosted
from pathlib import Path


class GoldenTests(unittest.TestCase):
    def context(self):
        return dict(fixture_admission='QUALIFIED_DISPOSABLE_SESSION', profile_sha256='a'*64,
                    session_sha256='b'*64, app_executable_sha256='c'*64, core_install_receipt_sha256='d'*64,
                    bundle_id='dev.djconnect.mac', app_build='test', language='nl',
                    request_limit=4, model_attempts_per_turn=2, max_model_calls=8)

    def test_exact_inventory(self):
        c = golden.catalog()
        self.assertEqual(c['core_commit'], golden.CORE_COMMIT)
        self.assertEqual(len(c['families']), 39)
        self.assertEqual(sum(len(f['steps']) for f in c['families']), 167)
        ids = [s['id'] for f in c['families'] for s in f['steps']]
        self.assertEqual(len(set(ids)), 167)

    def test_whole_chain_is_pinned_and_unarmed(self):
        p = golden.plan(self.context(), ['ASKDJ-FLOW-information-not-action'])
        self.assertFalse(p['execute'])
        self.assertEqual(len(p['steps']), 4)
        self.assertEqual(p['steps'][1]['model_policy'], 'one_or_two')

    def test_budget_identity_and_new_language_fail_closed(self):
        for key, value in [('request_limit', 3), ('max_model_calls', 1),
                           ('session_sha256', ''), ('fixture_admission', 'PENDING'), ('language', 'fr')]:
            context = self.context(); context[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                golden.plan(context, ['ASKDJ-FLOW-information-not-action'])

    def test_hosted_configuration_binds_only_exact_target_and_preserves_testroot(self):
        data={'TestConfigurations': [{'TestTargets': [{'BlueprintName': 'DJConnectAskDJGoldenHosted',
              'TestHostPath': '__TESTROOT__/Debug/DJConnect.app', 'EnvironmentVariables': {'existing': 'kept'}}]}]}
        configured=run_hosted.configure(data, Path('/private/products'), Path('/private/plan'), Path('/private/results'))
        target=configured['TestConfigurations'][0]['TestTargets'][0]
        self.assertEqual(target['TestHostPath'], '/private/products/Debug/DJConnect.app')
        self.assertEqual(target['EnvironmentVariables']['existing'], 'kept')
        self.assertEqual(target['EnvironmentVariables']['DJCONNECT_ASKDJ_GOLDEN_PLAN'], '/private/plan')
        with self.assertRaises(ValueError):
            run_hosted.configure({}, Path('/p'), Path('/plan'), Path('/out'))

    def evidence(self):
        # Only a parser regression fixture, deliberately labelled non-runtime.
        keys = dict(run_id='test-run', catalog_sha256=golden.CATALOG_SHA, profile_sha256='a'*64,
                    session_sha256='b'*64, app_executable_sha256='c'*64, core_install_receipt_sha256='d'*64)
        case = dict(id='ASKDJ-FLOW-information-not-action-step-2', client_message_sha256='e'*64, server_turn_sha256='f'*64,
                    answer_sha256='1'*64, question_sha256='2'*64, session_entry_sha256='5'*64,
                    native_bubble_rendered=True, model_policy='one_or_two',
                    status='CLIENT_ACCEPTED_PROVIDER_UNVERIFIED')
        native = dict(keys, cases=[case], expected_case_ids=['ASKDJ-FLOW-information-not-action-step-2'], max_model_calls=2,
                      model_attempts_per_turn=2, status='CLIENT_EXERCISED_NOT_RELEASE_PASS')
        row = dict(case, semantic_verdict='PASS', effects_verdict='PASS',
                   provider_attempts=[dict(provider_receipt_sha256='3'*64, model='synthetic-test-only',
                                           attempted=True, completed=True, output_tokens=4)])
        producer = dict(keys, producer_commit='4'*40, export_status='QUALIFIED', cases=[row],
                        unattributed_provider_attempts=0, observed_total_provider_attempts=1)
        return native, producer

    def test_missing_real_provider_completion_never_passes(self):
        n,p = self.evidence()
        for field,value in [('provider_attempts', []), ('semantic_verdict', 'FAIL'), ('answer_sha256', 'other')]:
            q=copy.deepcopy(p);q['cases'][0][field]=value
            self.assertEqual(golden.reconcile(n,q,'4'*40)['status'], 'FAIL')
        q=copy.deepcopy(p);q['cases'][0]['provider_attempts'][0]['completed']=False
        self.assertEqual(golden.reconcile(n,q,'4'*40)['status'], 'FAIL')

    def test_unqualified_or_mismatched_turn_and_reused_attempt_fail(self):
        n,p=self.evidence()
        for key,value in [('export_status','PENDING'),('run_id','other'),('cases',[])]:
            q=copy.deepcopy(p);q[key]=value
            self.assertEqual(golden.reconcile(n,q,'4'*40)['status'], 'FAIL')
        q=copy.deepcopy(p);q['cases'][0]['provider_attempts']*=2
        self.assertIn('missing_or_reused_provider_receipt', golden.reconcile(n,q,'4'*40)['findings'])

    def test_accepted_client_without_producer_is_not_release_pass(self):
        n,p=self.evidence()
        subset=golden.reconcile(n,p,'4'*40)
        self.assertEqual(subset['status'], 'PASS_SELECTED_SET')
        self.assertEqual(golden.release_gate([subset])['status'], 'FAIL')
        zero_n,zero_p=copy.deepcopy(n),copy.deepcopy(p)
        zero_n['cases'][0]['model_policy']='zero'
        zero_p['cases'][0]['provider_attempts']=[]
        zero_p['observed_total_provider_attempts']=0
        self.assertEqual(golden.reconcile(zero_n,zero_p,'4'*40)['status'], 'PASS_SELECTED_SET')
        n['status']='RUNNING'
        self.assertEqual(golden.reconcile(n,p,'4'*40)['status'], 'FAIL')

    def test_full_release_coverage_and_candidate_binding(self):
        ids=[s['id'] for f in golden.catalog()['families'] for s in f['steps']]
        r=dict(status='PASS_SELECTED_SET', paid_attempts=1, passed_case_ids=ids, catalog_sha256=golden.CATALOG_SHA,
               app_executable_sha256='a'*64, core_install_receipt_sha256='b'*64, producer_commit='c'*40)
        self.assertEqual(golden.release_gate([r])['status'], 'PASS_CORE_CLIENT_GOLDEN')
        zero=copy.deepcopy(r);zero['paid_attempts']=0
        self.assertIn('no_real_model_calls',golden.release_gate([zero])['findings'])
        self.assertEqual(golden.release_gate([r,r])['status'], 'FAIL')
        t=copy.deepcopy(r);t['app_executable_sha256']='other'
        self.assertEqual(golden.release_gate([r,t])['status'], 'FAIL')


if __name__ == '__main__':
    unittest.main()
