import math
import random


def circle_area(radius):
    return math.pi * radius ** 2


def hypotenuse(a, b):
    return math.sqrt(a * a + b * b)


def pick_random(items, seed):
    random.seed(seed)
    return random.choice(items)
