import unittest

from solution import ticket_price


class TicketPriceTest(unittest.TestCase):
    def test_adult_pays_base_with_default_argument(self):
        self.assertEqual(ticket_price(30), 12000)

    def test_child_under_8_pays_half(self):
        self.assertEqual(ticket_price(5), 6000)

    def test_child_with_custom_base(self):
        self.assertEqual(ticket_price(3, 9000), 4500)

    def test_senior_gets_discount(self):
        self.assertEqual(ticket_price(70), 10000)

    def test_boundary_age_8_is_not_child_price(self):
        self.assertEqual(ticket_price(8), 12000)

    def test_boundary_age_65_gets_discount(self):
        self.assertEqual(ticket_price(65), 10000)

    def test_boundary_age_0_is_child_price(self):
        self.assertEqual(ticket_price(0), 6000)

    def test_custom_base_for_senior(self):
        self.assertEqual(ticket_price(80, 10000), 8000)
