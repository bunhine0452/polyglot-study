def sort_students(students):
    return sorted(students, key=lambda s: (-s["score"], s["name"]))
