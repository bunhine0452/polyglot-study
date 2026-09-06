import unittest

from solution import parse_amount, withdraw


class ParseAmountTests(unittest.TestCase):
    def test_numeric_string(self):
        self.assertEqual(parse_amount("100"), 100)

    def test_negative_number_is_valid_integer(self):
        self.assertEqual(parse_amount("-7"), -7)

    def test_not_a_number_returns_zero(self):
        self.assertEqual(parse_amount("abc"), 0)

    def test_empty_string_returns_zero(self):
        self.assertEqual(parse_amount(""), 0)


class WithdrawTests(unittest.TestCase):
    def test_normal_withdraw_returns_remaining_balance(self):
        self.assertEqual(withdraw(1000, 300), 700)

    def test_withdraw_exact_balance_leaves_zero(self):
        self.assertEqual(withdraw(1000, 1000), 0)

    def test_over_balance_raises_value_error(self):
        with self.assertRaises(ValueError):
            withdraw(1000, 1001)

    def test_zero_amount_raises_value_error(self):
        with self.assertRaises(ValueError):
            withdraw(1000, 0)

    def test_negative_amount_raises_value_error(self):
        with self.assertRaises(ValueError):
            withdraw(1000, -500)
