import unittest
from solution import make_profile

class TestMakeProfile(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(make_profile("민수", 20, "부산", "축구"), "민수(20세) - 부산, 취미: 축구")

    def test_defaults(self):
        self.assertEqual(make_profile("지은", 25), "지은(25세) - 서울, 취미: 없음")

    def test_partial_keyword(self):
        self.assertEqual(make_profile("철수", 30, hobby="독서"), "철수(30세) - 서울, 취미: 독서")

    def test_keyword_reversed_order(self):
        self.assertEqual(make_profile(hobby="요리", city="대전", age=28, name="수아"), "수아(28세) - 대전, 취미: 요리")

    def test_age_zero(self):
        self.assertEqual(make_profile("아기", 0), "아기(0세) - 서울, 취미: 없음")
