import json
import time
from game.geometry import get_distance
from game.keypoints import BODY_PARTS

class Choreography():
    # Constructor
    def __init__(self):
        self.choreography = {}
        self.current_move = 1
        self.start_time = time.time()
        self.score = 0
 
    def load_choreography(self):
        file = open('choreography/dance.json')
        self.choreography = json.load(file)
        print("Choreography has " + str(len(self.choreography)) + " moves!")
        for key, value in self.choreography.items():
            print("Dance has " + str(key))

    def start_choreography(self):
        self.score = 0
        self.start_time = time.time()

    def update_dance(self, player_pose):
        change_time = self.choreography["move_" + str(self.current_move)]["time"]
        if (time.time() - self.start_time) > change_time:
            self.score += self.calculate_player_score(player_pose)
            self.current_move += 1
            # Reset moves for simplicity
            if self.current_move >= len(self.choreography):
                self.current_move = 1
                self.start_time = time.time()

    def get_score(self):
        return str(self.score)
    
    def get_current_move(self):
        return self.choreography["move_" + str(self.current_move)]["pose"]
    