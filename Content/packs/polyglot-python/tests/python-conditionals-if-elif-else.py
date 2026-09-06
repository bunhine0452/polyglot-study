import unittest

from solution import ticket_price


class TicketPriceTest(unittest.TestCase):
    def test_영아는_무료다(self):
        self.assertEqual(ticket_price(3, False), 0)

    def test_음수_나이도_8_미만으로_처리한다(self):
        self.assertEqual(ticket_price(-1, False), 0)

    def test_경계값_8세_학생은_5000원이다(self):
        self.assertEqual(ticket_price(8, True), 5000)

    def test_경계값_8세_비학생은_8000원이다(self):
        self.assertEqual(ticket_price(8, False), 8000)

    def test_학생인_성인은_5000원이다(self):
        self.assertEqual(ticket_price(20, True), 5000)

    def test_일반_성인은_8000원이다(self):
        self.assertEqual(ticket_price(30, False), 8000)

    def test_경계값_65세는_학생이어도_3000원이다(self):
        self.assertEqual(ticket_price(65, True), 3000)

    def test_고령자는_비학생이면_3000원이다(self):
        self.assertEqual(ticket_price(70, False), 3000)
