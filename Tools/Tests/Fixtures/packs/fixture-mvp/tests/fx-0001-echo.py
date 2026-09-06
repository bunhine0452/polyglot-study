import unittest

from solution import double


class DoubleTests(unittest.TestCase):
    def test_positive(self):
        self.assertEqual(double(3), 6)

    def test_zero(self):
        self.assertEqual(double(0), 0)
