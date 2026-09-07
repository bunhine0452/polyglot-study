import unittest
from solution import normalize_phone

class TestNormalizePhone(unittest.TestCase):
    def test_basic_dashes(self):
        self.assertEqual(normalize_phone("010-1234-5678"), "01012345678")

    def test_empty_string(self):
        self.assertEqual(normalize_phone(""), "")

    def test_spaces_and_edges(self):
        self.assertEqual(normalize_phone("  010 1234 5678 "), "01012345678")

    def test_already_clean(self):
        self.assertEqual(normalize_phone("0212345678"), "0212345678")

    def test_mixed_separators(self):
        self.assertEqual(normalize_phone(" 02 - 123 - 4567 "), "021234567")
