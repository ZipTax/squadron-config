"""Validate case storage and configured capabilities without calling external services."""
import copy
import json
import unittest

import hcl2
import yaml
from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from test_rate_findings import ROOT, blocks, mission, unquote_keys


class SlackCaseContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        schemas = ROOT / 'docs/schemas'
        cls.schema = json.loads((schemas / 'rate-ticket-checkpoint.schema.json').read_text())
        production = json.loads((schemas / 'production-evidence.schema.json').read_text())
        registry = Registry().with_resource('production-evidence.schema.json', Resource.from_contents(production))
        cls.validator = Draft202012Validator(cls.schema, registry=registry)
        cls.case = json.loads((schemas / 'examples/rate-ticket-checkpoint.slack.json').read_text())

    def test_old_and_extended_records_validate(self):
        Draft202012Validator.check_schema(self.schema)
        for path in (ROOT / 'docs/schemas/examples').glob('rate-ticket-checkpoint.*'):
            with self.subTest(path=path.name):
                self.validator.validate(yaml.safe_load(path.read_text()))

    def test_pending_edit_and_closed_case_keep_editable_root(self):
        case = copy.deepcopy(self.case)
        before = case['slack']['published_text']
        case['slack'].update(root_text=before.replace('Blocked on question', 'Fixing'), update_pending=True)
        self.validator.validate(case)
        self.assertNotEqual(case['slack']['root_text'], case['slack']['published_text'])
        case['human_wait']['state'] = 'resolved'
        case['human_wait']['answer'] = 'Use the scheduled release window.'
        case['human_wait']['answer_source'] = 'Squadron human answer'
        case['case_state'] = 'closed'
        case['slack'].update(published_text=case['slack']['root_text'], update_pending=False)
        self.validator.validate(case)
        self.assertEqual(case['slack']['root_message_id'], self.case['slack']['root_message_id'])

    def test_bad_question_channel_and_incomplete_slack_state_are_rejected(self):
        case = copy.deepcopy(self.case)
        case['human_wait']['channel'] = 'invented'
        self.assertFalse(self.validator.is_valid(case))
        case = copy.deepcopy(self.case)
        del case['slack']['root_message_id']
        self.assertFalse(self.validator.is_valid(case))

    def test_all_hcl_parses_and_skill_files_exist(self):
        for path in ROOT.rglob('*.hcl'):
            if '.squadron' in path.parts:
                continue
            with path.open() as source:
                hcl2.load(source)
        with (ROOT / 'skills.hcl').open() as source:
            skills = blocks(unquote_keys(hcl2.load(source))['skill'])
        import re
        for skill in skills.values():
            match = re.search(r'load\("([^\"]+)"\)', skill['instructions'])
            self.assertIsNotNone(match)
            self.assertTrue((ROOT / match.group(1)).is_file())

    def test_minimal_routes_and_stage_capabilities(self):
        with (ROOT / 'agents.hcl').open() as source:
            agents = blocks(unquote_keys(hcl2.load(source))['agent'])
        for name in ('rate_triage', 'rate_fix', 'rate_finalize'):
            config = mission(name)
            required = {key for key, value in blocks(config['input']).items() if 'default' not in value}
            self.assertLessEqual(required, {'issue', 'entry_stage'})
            self.assertIn('${memories.rate_checkpoint}', config['memories'])
            for task in blocks(config['task']).values():
                for ref in task['agents']:
                    agent = agents[ref.removeprefix('${agents.').removesuffix('}')]
                    self.assertTrue({'${builtins.human.ask}', '${builtins.gateway.post}', '${builtins.gateway.edit}'} <= set(agent['tools']))
                    self.assertTrue({'${skills.rate_case}', '${skills.case_slack}'} <= set(agent['skills']))


if __name__ == '__main__':
    unittest.main()
