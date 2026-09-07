import unittest
from solution import unique_values

class UniqueValuesTest(unittest.TestCase):
    def test_basic_numbers(self):
        self.assertEqual(unique_values([3, 1, 3, 2, 1, 3]), [3, 1, 2])

    def test_empty_list(self):
        self.assertEqual(unique_values([]), [])

    def test_all_duplicates(self):
        self.assertEqual(unique_values([5, 5, 5, 5]), [5])

    def test_strings_keep_order(self):
        self.assertEqual(unique_values(["사과", "바나나", "사과", "포도"]), ["사과", "바나나", "포도"])
