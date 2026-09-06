import unittest
from solution import sum_until_negative


class SumUntilNegativeTest(unittest.TestCase):
    def test_stops_at_first_negative(self):
        self.assertEqual(sum_until_negative([3, 5, 0, 7, -1, 100]), 15)

    def test_no_negative_sums_all(self):
        self.assertEqual(sum_until_negative([2, 4, 6]), 12)

    def test_empty_list_returns_zero(self):
        self.assertEqual(sum_until_negative([]), 0)

    def test_zeros_are_skipped(self):
        self.assertEqual(sum_until_negative([0, 0, 4, -2, 9]), 4)

    def test_first_element_negative_returns_zero(self):
        self.assertEqual(sum_until_negative([-5, 10]), 0)
