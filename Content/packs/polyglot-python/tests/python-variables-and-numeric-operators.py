import unittest

from solution import share, leftover


class TestShareAndLeftover(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(share(17, 5), 3)
        self.assertEqual(leftover(17, 5), 2)

    def test_zero_total_boundary(self):
        self.assertEqual(share(0, 4), 0)
        self.assertEqual(leftover(0, 4), 0)

    def test_even_divide(self):
        self.assertEqual(share(20, 4), 5)
        self.assertEqual(leftover(20, 4), 0)

    def test_fewer_than_people(self):
        self.assertEqual(share(7, 10), 0)
        self.assertEqual(leftover(7, 10), 7)

    def test_one_person(self):
        self.assertEqual(share(9, 1), 9)
        self.assertEqual(leftover(9, 1), 0)
