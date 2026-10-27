"""Contract checks; these do not substitute for a live Devin or Squadron run."""
import json
import unittest
from pathlib import Path

import hcl2
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]


def unquote_keys(value):
    if isinstance(value, dict):
        return {key.strip('"'): unquote_keys(item) for key, item in value.items()}
    if isinstance(value, list):
        return [unquote_keys(item) for item in value]
    if isinstance(value, str) and value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    return value


def mission(name):
    with (ROOT / "missions" / f"{name.replace('_', '-')}.hcl").open() as source:
        return unquote_keys(hcl2.load(source))["mission"][0][name]


def blocks(items):
    return {key: value for item in items for key, value in item.items()}


class FindingsContract(unittest.TestCase):
    def test_examples_match_attached_schemas(self):
        for prefix, schema_name in (("rate-investigation", "rate_investigation"),
                                    ("rate-fix", "rate-fix")):
            schema = json.loads((ROOT / "devin-playbooks/schemas" / f"{schema_name}.json").read_text())
            Draft202012Validator.check_schema(schema)
            validator = Draft202012Validator(schema)
            for path in (ROOT / "devin-playbooks/examples").glob(f"{prefix}.*.json"):
                with self.subTest(example=path.name):
                    report = json.loads(path.read_text())
                    validator.validate(report)
                    ids = [finding["id"] for finding in report["findings"]]
                    self.assertEqual(len(ids), len(set(ids)))
                    checkpoint = json.loads((ROOT / "docs/schemas/rate-ticket-checkpoint.schema.json").read_text())
                    question_validator = Draft202012Validator(checkpoint["$defs"]["blocker_question"])
                    for question in report["human_questions"]:
                        question_validator.validate(question)

    def test_multipart_example_retains_independent_decisions(self):
        report = json.loads((ROOT / "devin-playbooks/examples/rate-investigation.multiple-issues.json").read_text())
        a, b, c = report["findings"]
        self.assertNotEqual(a["start_date"]["date"], b["start_date"]["date"])
        self.assertNotEqual(a["authority"], b["authority"])
        self.assertEqual(c["start_date"]["status"], "unresolved")
        self.assertIsNone(c["start_date"]["date"])
        self.assertIn("Finding " + c["id"] + ":", report["human_questions"][0]["context"])
        self.assertEqual(report["outcome"], "needs_human")

    def test_every_consumer_receives_findings(self):
        fix = mission("rate_fix")
        tasks = blocks(fix["task"])
        for name in ("develop", "author_tests", "audit", "bruno_tests"):
            with self.subTest(task=name):
                self.assertIn("${memories.rate_checkpoint}", fix["memories"])
                self.assertIn("findings", blocks(tasks[name]["output"][0]["field"]))
        finalize = mission("rate_finalize")
        self.assertIn("findings", blocks(finalize["input"]))
        for name in ("verify_wai", "record_learnings"):
            self.assertIn("${memories.rate_checkpoint}", finalize["memories"])

    def test_cross_mission_routes_preserve_findings(self):
        checked = 0
        for name in ("rate_triage", "rate_fix"):
            for task in blocks(mission(name)["task"]).values():
                for router in task.get("router", []):
                    for route in router["route"]:
                        if "missions.rate_finalize" in route["target"] or "missions.rate_fix" in route["target"]:
                            self.assertIn("findings", route["condition"])
                            checked += 1
        self.assertGreaterEqual(checked, 4)

    def test_legacy_input_is_not_silently_discarded(self):
        fix = mission("rate_fix")
        inputs = blocks(fix["input"])
        self.assertIn("target_authority", inputs)
        self.assertNotEqual(inputs["findings"]["default"], "[]")
        for name, task in blocks(fix["task"]).items():
            if name in ("develop", "author_tests", "audit", "bruno_tests"):
                self.assertEqual(inputs["target_authority"]["default"], "")
                self.assertFalse(blocks(task["output"][0]["field"])["findings"]["required"])
        tasks = blocks(fix["task"])
        self.assertTrue(blocks(tasks["audit"]["output"][0]["field"])["verdict"]["required"])
        self.assertTrue(blocks(tasks["bruno_tests"]["output"][0]["field"])["outcome"]["required"])
        assess = blocks(mission("rate_triage")["task"])["assess_investigation"]
        self.assertFalse(blocks(assess["output"][0]["field"])["findings"]["required"])

    def test_case_record_preserves_complete_multipart_findings(self):
        report = json.loads((ROOT / "devin-playbooks/examples/rate-investigation.multiple-issues.json").read_text())
        case = json.loads((ROOT / "docs/schemas/examples/rate-ticket-checkpoint.slack.json").read_text())
        self.assertEqual(case["context"]["findings"], report["findings"])
        self.assertEqual(json.loads(json.dumps(case))["context"]["findings"], report["findings"])

    def test_date_schema_uses_no_conditional_or_format_validation(self):
        for name in ("rate_investigation", "rate-fix"):
            schema = json.loads((ROOT / "devin-playbooks/schemas" / f"{name}.json").read_text())
            start_date = schema["properties"]["findings"]["items"]["properties"]["start_date"]
            serialized = json.dumps(start_date)
            for keyword in ("allOf", "if", "then", "else", "format"):
                self.assertNotIn(f'"{keyword}":', serialized)


if __name__ == "__main__":
    unittest.main()
