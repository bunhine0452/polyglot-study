import unittest
from solution import BankAccount

class TestBankAccount(unittest.TestCase):
    def test_deposit_adds_balance(self):
        acc = BankAccount("kim", 1000)
        self.assertTrue(acc.deposit(500))
        self.assertEqual(acc.balance, 1500)

    def test_withdraw_success(self):
        acc = BankAccount("lee", 1000)
        self.assertTrue(acc.withdraw(400))
        self.assertEqual(acc.balance, 600)

    def test_withdraw_insufficient_keeps_balance(self):
        acc = BankAccount("park", 100)
        self.assertFalse(acc.withdraw(500))
        self.assertEqual(acc.balance, 100)

    def test_default_balance_and_zero_deposit(self):
        acc = BankAccount("choi")
        self.assertEqual(acc.balance, 0)
        self.assertTrue(acc.deposit(0))
        self.assertEqual(acc.balance, 0)
