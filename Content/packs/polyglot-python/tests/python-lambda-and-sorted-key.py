import unittest
from solution import sort_students

class SortStudentsTest(unittest.TestCase):
    def test_basic_order(self):
        students = [{"name": "민수", "score": 82}, {"name": "지우", "score": 95}, {"name": "하늘", "score": 88}]
        result = sort_students(students)
        self.assertEqual([s["name"] for s in result], ["지우", "하늘", "민수"])

    def test_tie_broken_by_name(self):
        students = [{"name": "철수", "score": 90}, {"name": "영희", "score": 90}]
        result = sort_students(students)
        self.assertEqual([s["name"] for s in result], ["영희", "철수"])

    def test_empty_list(self):
        self.assertEqual(sort_students([]), [])

    def test_original_untouched(self):
        students = [{"name": "민수", "score": 82}, {"name": "지우", "score": 95}]
        sort_students(students)
        self.assertEqual(students, [{"name": "민수", "score": 82}, {"name": "지우", "score": 95}])
