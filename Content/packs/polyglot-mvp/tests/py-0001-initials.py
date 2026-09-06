import unittest

from solution import initials


class InitialsTests(unittest.TestCase):
    def test_two_words(self):
        self.assertEqual(initials("ada lovelace"), "AL")

    def test_collapses_extra_spaces(self):
        self.assertEqual(initials("  grace   brewster  hopper "), "GBH")

    def test_empty(self):
        self.assertEqual(initials(""), "")
