import unittest
from solution import summary


class SummaryTest(unittest.TestCase):
    def test_basic_word(self):
        self.assertEqual(summary("python"), "[PYTHON] len=6")

    def test_strip_outer_spaces(self):
        self.assertEqual(summary("  hi there  "), "[HI THERE] len=8")

    def test_empty_string(self):
        self.assertEqual(summary(""), "[] len=0")

    def test_only_spaces(self):
        self.assertEqual(summary("   "), "[] len=0")

    def test_single_char_with_spaces(self):
        self.assertEqual(summary(" a "), "[A] len=1")


if __name__ == "__main__":
    unittest.main()
