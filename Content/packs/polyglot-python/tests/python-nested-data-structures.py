import unittest
from solution import total_scores

class TotalScoresTest(unittest.TestCase):
    def test_empty_roster(self):
        self.assertEqual(total_scores([]), 0)

    def test_single_student(self):
        students = [{"name": "민수", "scores": [90, 85]}]
        self.assertEqual(total_scores(students), 175)

    def test_multiple_students(self):
        students = [
            {"name": "민수", "scores": [90, 85]},
            {"name": "지영", "scores": [78, 92]},
            {"name": "도윤", "scores": [100]},
        ]
        self.assertEqual(total_scores(students), 445)

    def test_student_with_empty_scores(self):
        students = [
            {"name": "철수", "scores": []},
            {"name": "영희", "scores": [50]},
        ]
        self.assertEqual(total_scores(students), 50)

if __name__ == "__main__":
    unittest.main()
