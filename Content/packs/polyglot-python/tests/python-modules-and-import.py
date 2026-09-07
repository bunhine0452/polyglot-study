import unittest
import math

from solution import circle_area, hypotenuse, pick_random


class ModuleFunctionsTest(unittest.TestCase):
    def test_circle_area_basic(self):
        self.assertAlmostEqual(circle_area(2), math.pi * 4)

    def test_circle_area_zero_boundary(self):
        self.assertEqual(circle_area(0), 0.0)

    def test_hypotenuse_3_4_5(self):
        self.assertAlmostEqual(hypotenuse(3, 4), 5.0)

    def test_hypotenuse_zero_boundary(self):
        self.assertEqual(hypotenuse(0, 0), 0.0)

    def test_pick_random_returns_member(self):
        items = ["가위", "바위", "보"]
        self.assertIn(pick_random(items, 7), items)

    def test_pick_random_seed_reproducible(self):
        items = [1, 2, 3, 4, 5]
        self.assertEqual(pick_random(items, 42), pick_random(items, 42))
