import unittest

from solution import analyze_words


class TestAnalyzeWords(unittest.TestCase):
    def test_basic_counting(self):
        result = analyze_words("apple banana apple", top_n=3)
        self.assertEqual(result, [("apple", 2), ("banana", 1)])

    def test_case_insensitive(self):
        result = analyze_words("Banana APPLE banana apple Cherry", top_n=2)
        self.assertEqual(result, [("apple", 2), ("banana", 2)])

    def test_empty_text(self):
        self.assertEqual(analyze_words("", top_n=3), [])

    def test_ties_sorted_alphabetically(self):
        result = analyze_words("b a c a b c", top_n=3)
        self.assertEqual(result, [("a", 2), ("b", 2), ("c", 2)])

    def test_top_n_larger_than_distinct(self):
        result = analyze_words("dog cat dog", top_n=10)
        self.assertEqual(result, [("dog", 2), ("cat", 1)])

    def test_top_n_default_is_three(self):
        result = analyze_words("x x y y z z w")
        self.assertEqual(result, [("x", 2), ("y", 2), ("z", 2), ("w", 1)][:3])
