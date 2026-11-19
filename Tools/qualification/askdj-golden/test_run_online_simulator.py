"""Preflight regressions for the explicitly armed simulator runner."""

import json
from pathlib import Path
import unittest

from run_online_simulator import CATALOGUE, configure


class OnlineSimulatorPlanTests(unittest.TestCase):
    def setUp(self):
        self.plan = dict(
            execute=True, fixture='DISPOSABLE_ONLINE_SESSION',
            session_id='session-a', profile_id='profile-a', output_id='output-a', artist='Fixture artist',
            reply_patterns={entry['id']: 'Expected fixture reply'
                            for entry in json.loads(CATALOGUE.read_text())['entries']},
        )
        self.spec = {'TestConfigurations': [{'TestTargets': [{
            'BlueprintName': 'DJConnectIOSUITests', 'TestBundlePath': '__TESTROOT__/runner',
        }]}]}

    def test_online_values_are_injected_into_runner_only(self):
        result = configure(self.spec, Path('/test/build'), self.plan)
        target = result['TestConfigurations'][0]['TestTargets'][0]
        self.assertEqual(target['TestBundlePath'], '/test/build/runner')
        self.assertEqual(target['EnvironmentVariables']['DJCONNECT_ONLINE_SESSION'], 'session-a')
        self.assertNotIn('UITargetAppEnvironmentVariables', target)
        self.assertNotIn('EnvironmentVariables', self.spec['TestConfigurations'][0]['TestTargets'][0])

    def test_unarmed_or_wrong_catalogue_fails_before_launch(self):
        with self.assertRaisesRegex(ValueError, 'not_armed'):
            configure(self.spec, Path('/test/build'), dict(self.plan, execute=False))
        patterns = dict(self.plan['reply_patterns'])
        patterns.pop('listen.forecast')
        patterns['wrong'] = 'fixture'
        with self.assertRaisesRegex(ValueError, 'fourteen_reply_expectations_required'):
            configure(self.spec, Path('/test/build'), dict(self.plan, reply_patterns=patterns))
