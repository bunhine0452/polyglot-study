import unittest

from solution import count_char


class CountCharTest(unittest.TestCase):
    def test_repeated_letter(self):
        self.assertEqual(count_char("banana", "a"), 3)

    def test_empty_string(self):
        self.assertEqual(count_char("", "x"), 0)

    def test_not_present(self):
        self.assertEqual(count_char("python", "z"), 0)

    def test_case_insensitive(self):
        self.assertEqual(count_char("Apple", "a"), 1)

    def test_count_space(self):
        self.assertEqual(count_char("a b c", " "), 2)
