import unittest
from unittest.mock import Mock

from app.services.voice_matching import match_score, spoken_tokens, suggest_components


class VoiceMatchingTests(unittest.TestCase):
    def test_reported_transcription(self):
        self.assertEqual(spoken_tokens("A Gravity I to see Digital Wattmeter"),
                         spoken_tokens("Gravity I2C Digital Wattmeter"))
        self.assertGreater(match_score("gravity wattmeter", "Gravity I2C Digital Wattmeter"), 0.8)

    def test_unrelated_query_has_no_suggestion(self):
        self.assertLess(match_score("banana", "Gravity I2C Digital Wattmeter"), 0.55)
        self.assertEqual(match_score("please", "Gravity I2C Digital Wattmeter"), 0)

    def test_ranking_codes_limit_and_scope(self):
        db = Mock()
        db.execute.return_value = [
            ("Gravity temperature sensor", "SEN-1", None),
            ("Gravity I2C Digital Wattmeter", "MET-1", None),
            ("Gravity wattmeter pro", "MET-2", None),
            ("Gravity wattmeter mini", "MET-3", None),
            ("Gravity wattmeter extra", "MET-4", None),
        ]
        matches = suggest_components(db, "workspace-test", "a gravity i to see digital wattmeter")
        self.assertEqual(matches[0]["inventory_code"], "MET-1")
        self.assertLessEqual(len(matches), 3)
        self.assertTrue(all(item["inventory_code"] != "SEN-1" for item in matches))
        statement = db.execute.call_args.args[0]
        self.assertIn("workspace-test", statement.compile().params.values())
        self.assertIn("is_archived IS false", str(statement))


if __name__ == "__main__":
    unittest.main()
