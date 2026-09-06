import unittest
from solution import filter_banned

class FilterBannedTests(unittest.TestCase):
    def test_filters_out_banned_words(self):
        self.assertEqual(
            filter_banned(["apple", "banana", "apple"], ["banana"]),
            ["apple", "apple"],
        )

    def test_empty_words_returns_empty_list(self):
        self.assertEqual(filter_banned([], ["banana"]), [])

    def test_all_words_banned_returns_empty_list(self):
        self.assertEqual(filter_banned(["a", "b", "c"], ["a", "b", "c"]), [])

    def test_empty_banned_keeps_everything(self):
        self.assertEqual(filter_banned(["x", "y"], []), ["x", "y"])

    def test_original_lists_are_untouched(self):
        words = ["apple", "banana"]
        banned = ["banana"]
        filter_banned(words, banned)
        self.assertEqual(words, ["apple", "banana"])
        self.assertEqual(banned, ["banana"])
