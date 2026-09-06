def ticket_price(age, is_student):
    if age < 8:
        return 0
    elif age >= 65:
        return 3000
    elif is_student:
        return 5000
    else:
        return 8000
