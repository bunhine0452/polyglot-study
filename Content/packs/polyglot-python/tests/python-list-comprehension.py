import unittest
from solution import square_evens

class SquareEvensTest(unittest.TestCase):
    def test_mixed_numbers(self):
        self.assertEqual(square_evens([1, 2, 3, 4, 5, 6]), [4, 16, 36])

    def test_empty_list(self):
        self.assertEqual(square_evens([]), [])

    def test_no_evens(self):
        self.assertEqual(square_evens([1, 3, 5]), [])

    def test_zero_and_negatives(self):
        self.assertEqual(square_evens([0, -2, -3, 4]), [0, 4, 16])

    def test_duplicates_keep_order(self):
        self.assertEqual(square_evens([2, 2, 3, 4]), [4, 4, 16])

    def test_original_list_unchanged(self):
        data = [1, 2, 3, 4]
        square_evens(data)
        self.assertEqual(data, [1, 2, 3, 4])
