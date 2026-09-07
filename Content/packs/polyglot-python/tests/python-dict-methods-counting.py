import unittest
from solution import count_elements

class TestCountElements(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(count_elements(["a", "b", "a"]), {"a": 2, "b": 1})

    def test_empty_list(self):
        self.assertEqual(count_elements([]), {})

    def test_all_duplicates(self):
        self.assertEqual(count_elements([1, 1, 1]), {1: 3})

    def test_single_element(self):
        self.assertEqual(count_elements(["x"]), {"x": 1})

    def test_counts_dict_keys(self):
        result = count_elements(["가", "나", "가", "다", "나", "가"])
        self.assertEqual(result, {"가": 3, "나": 2, "다": 1})
