import unittest
from solution import countdown

class TestCountdown(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(list(countdown(3)), [3, 2, 1])

    def test_single(self):
        self.assertEqual(list(countdown(1)), [1])

    def test_zero(self):
        self.assertEqual(list(countdown(0)), [])

    def test_negative(self):
        self.assertEqual(list(countdown(-5)), [])
