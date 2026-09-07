import unittest
import json
from solution import csv_to_json


class TestCsvToJson(unittest.TestCase):
    def test_two_data_rows(self):
        text = "name,score\nAmy,90\nBo,85"
        self.assertEqual(
            json.loads(csv_to_json(text)),
            [{"name": "Amy", "score": "90"}, {"name": "Bo", "score": "85"}],
        )

    def test_values_stay_strings(self):
        text = "name,score\nAmy,90"
        record = json.loads(csv_to_json(text))[0]
        self.assertIsInstance(record["score"], str)

    def test_header_only_returns_empty_list(self):
        self.assertEqual(csv_to_json("name,score"), "[]")

    def test_empty_text_returns_empty_list(self):
        self.assertEqual(csv_to_json(""), "[]")

    def test_korean_is_not_escaped(self):
        text = "이름,점수\n김철수,90"
        self.assertIn("김철수", csv_to_json(text))
