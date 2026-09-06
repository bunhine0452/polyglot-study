import unittest
from io import StringIO
from contextlib import redirect_stdout

from solution import print_greeting

class PrintGreetingTest(unittest.TestCase):
    def _capture(self, name):
        buf = StringIO()
        with redirect_stdout(buf):
            print_greeting(name)
        return buf.getvalue()

    def test_basic_name(self):
        self.assertEqual(self._capture("지수"), "안녕하세요, 지수 님!\n")

    def test_empty_name(self):
        self.assertEqual(self._capture(""), "안녕하세요,  님!\n")

    def test_two_calls(self):
        buf = StringIO()
        with redirect_stdout(buf):
            print_greeting("철수")
            print_greeting("영희")
        self.assertEqual(buf.getvalue(), "안녕하세요, 철수 님!\n안녕하세요, 영희 님!\n")
