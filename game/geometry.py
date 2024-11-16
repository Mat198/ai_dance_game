class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

def get_distance(p1, p2):
    distance = ((p1["x"] - p2["x"])**2 + (p1["y"] - p2["y"])**2)**(0.5)
    return distance