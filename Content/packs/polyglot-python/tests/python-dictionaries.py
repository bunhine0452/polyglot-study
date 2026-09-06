import unittest

from solution import total_price


class TotalPriceTest(unittest.TestCase):
    def test_same_item_ordered_twice(self):
        prices = {"latte": 4600}
        self.assertEqual(total_price(["latte", "latte"], prices), 9200)

    def test_unknown_item_counts_as_zero(self):
        prices = {"americano": 4100}
        self.assertEqual(total_price(["americano", "cake"], prices), 4100)

    def test_empty_order_returns_zero(self):
        prices = {"americano": 4100, "latte": 4600}
        self.assertEqual(total_price([], prices), 0)

    def test_empty_prices_all_items_free(self):
        self.assertEqual(total_price(["tea", "soda"], {}), 0)

    def test_mixed_order(self):
        prices = {"americano": 4100, "latte": 4600, "juice": 5200}
        self.assertEqual(
            total_price(["americano", "juice", "latte"], prices),
            13900,
        )
