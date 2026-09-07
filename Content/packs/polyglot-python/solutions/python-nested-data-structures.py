def total_scores(students):
    total = 0
    for student in students:
        for score in student["scores"]:
            total += score
    return total
