import unittest
from solution import min_max

class TestMinMax(unittest.TestCase):
    def test_normal(self):
        self.assertEqual(min_max([3, 1, 2]), (1, 3))

    def test_single(self):
        self.assertEqual(min_max([7]), (7, 7))

    def test_empty(self):
        self.assertEqual(min_max([]), (None, None))

    def test_negatives(self):
        self.assertEqual(min_max([-5, -2, -9]), (-9, -2))
