import unittest
import os

from solution import save_and_load

TASK_FILE = "save_and_load_task.txt"


class SaveAndLoadTest(unittest.TestCase):
    def tearDown(self):
        if os.path.exists(TASK_FILE):
            os.remove(TASK_FILE)

    def test_roundtrip_returns_same_lines(self):
        lines = ["사과", "바나나", "체리"]
        self.assertEqual(save_and_load(lines, TASK_FILE), lines)

    def test_empty_list_returns_empty_list(self):
        self.assertEqual(save_and_load([], TASK_FILE), [])

    def test_empty_string_line_preserved(self):
        lines = ["첫 줄", "", "셋째 줄"]
        self.assertEqual(save_and_load(lines, TASK_FILE), lines)

    def test_whitespace_only_line_preserved(self):
        lines = ["  앞 공백", "가운데  공백", "  "]
        self.assertEqual(save_and_load(lines, TASK_FILE), lines)
