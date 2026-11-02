"""Check review resumption and the staging-only Bruno result contract."""
import copy
import json
import unittest

from jsonschema import Draft202012Validator

from test_rate_findings import ROOT, blocks, mission
import test_slack_case


class ReviewFollowupContract(unittest.TestCase):
    def test_review_is_reachable_from_lessons_and_direct_resume(self):
        tasks = blocks(mission('rate_finalize')['task'])
        for name in ('record_learnings', 'enter_finalize'):
            targets = {route['target'] for router in tasks[name]['router'] for route in router['route']}
            self.assertIn('${tasks.review_followup}', targets)
        self.assertIn('${agents.taxcloud_legacy_sql_reviewer}', tasks['review_followup']['agents'])

    def test_review_progress_survives_checkpoint_roundtrip(self):
        test_slack_case.SlackCaseContract.setUpClass()
        path = ROOT / 'docs/schemas/examples/rate-ticket-checkpoint.review.json'
        case = json.loads(path.read_text())
        case['review'].update(phase='assessing', feedback='Recheck the fixes I requested directly from Devin.',
                              round=2, pending_work='Collect current fix-session report.',
                              assessed_heads={'https://example.invalid/fix/1': 'prior-assessed-head'})
        test_slack_case.SlackCaseContract.validator.validate(case)
        recovered = json.loads(json.dumps(case))
        self.assertEqual(recovered['review'], case['review'])
        self.assertEqual(recovered['next_entry']['stage'], 'review_followup')
        self.assertEqual(recovered['case_state'], 'active')
        self.assertEqual(recovered['slack']['root_message_id'], case['slack']['root_message_id'])

    def test_bruno_examples_validate_and_production_is_rejected(self):
        schema = json.loads((ROOT / 'devin-playbooks/schemas/bruno-regression.json').read_text())
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        for path in (ROOT / 'devin-playbooks/examples').glob('bruno-regression.*.json'):
            report = json.loads(path.read_text())
            validator.validate(report)
            if report['outcome'] == 'completed':
                self.assertEqual(report['validation']['status'], 'passed')
                self.assertTrue(report['validation']['fix_version'])
                self.assertTrue(report['validation']['result_reference'])
            invalid = copy.deepcopy(report)
            invalid['validation']['environment'] = 'production'
            self.assertFalse(validator.is_valid(invalid))
        checkpoint = json.loads((ROOT / 'docs/schemas/rate-ticket-checkpoint.schema.json').read_text())
        self.assertEqual(checkpoint['properties']['context']['properties']['bruno_validation'],
                         schema['properties']['validation'])


if __name__ == '__main__':
    unittest.main()
