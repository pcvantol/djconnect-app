"""Synthetic checks for inventory comparison, without invoking the hosted adapter."""

import unittest

from audit_core_catalog import audit, execution_plan


def inventory(*steps):
    return {'families': [{'id': 'ask-dj', 'steps': list(steps)}]}


class CoreInventoryAuditTests(unittest.TestCase):
    def test_changed_question_and_reordered_chain_are_reported(self):
        first = {'id': 'first', 'question': 'Wie is dit?', 'model_policy': 'zero'}
        second = {'id': 'second', 'question': 'Wat is de titel?', 'model_policy': 'zero'}
        apple = inventory(first, second)
        self.assertEqual(audit(apple, apple)['status'], 'NO_STATIC_GAPS_FOUND')
        core = inventory(second, dict(first, question='Wie zingt dit?'))
        self.assertEqual(audit(apple, core)['findings']['ask-dj'], {
            'chain_mismatch': True,
            'changed_cases': ['first'],
        })

    def test_new_case_with_numeric_budget_still_needs_route_and_language_review(self):
        core = inventory({
            'id': 'history', 'model_policy': 'zero',
            'language': 'en', 'input_kind': 'owner_history_read',
        })
        self.assertEqual(audit(inventory(), core)['findings']['ask-dj'], {
            'chain_mismatch': True,
            'missing_cases': ['history'],
            'unsupported_language': ['history'],
            'requires_route_review': ['history'],
        })

    def test_duplicate_case_ids_do_not_silently_collapse(self):
        step = {'id': 'same', 'model_policy': 'zero'}
        with self.assertRaisesRegex(ValueError, 'duplicate_family_or_case'):
            audit(inventory(), inventory(step, step))

    def test_execution_plan_keeps_exact_changes_and_full_chain_order(self):
        first = {'id': 'first', 'model_policy': 'zero', 'question': 'Wat kun je?'}
        revised = dict(first, expected_answer='Compact help', owning_tests=['producer-test'])
        added = {'id': 'added', 'model_policy': 'producer-only', 'input_kind': 'owner_history_read'}
        tail = {'id': 'tail', 'model_policy': 'zero'}
        self.assertEqual(execution_plan(inventory(first, tail), inventory(revised, added, tail)), [{
            'id': 'ask-dj',
            'previous_order': ['first', 'tail'],
            'core_order': ['first', 'added', 'tail'],
            'cases': [
                {'change': 'changed', 'core': revised, 'previous': first},
                {'change': 'missing', 'core': added, 'previous': None},
            ],
        }])
