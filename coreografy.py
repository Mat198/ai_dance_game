import json
import time
import pygame
import cv2
import numpy as np

class Coreografy():
    # Constructor
    def __init__(self):
        self.coreografy = {}
        self.current_move = 1
        self.start_time = time.time()
        self.score = 0

    def start_coreografy(self):
        self.score = 0
        self.start_time = time.time()

    def update_dance(self, player_pose):
        change_time = self.coreografy["move_" + str(self.current_move)]["time"]
        if (time.time() - self.start_time) > change_time:
            self.score += self.calculate_player_score(player_pose)
            self.current_move += 1
            # Reset moves for simplicity
            if self.current_move >= len(self.coreografy):
                self.current_move = 1
                self.start_time = time.time()

    def get_score(self):
        return str(self.score)
    
    def load_coreografy(self):
        file = open('coreografy/dance.json')
        self.coreografy = json.load(file)
        print("Coreografy has " + str(len(self.coreografy)) + " moves!")
        for key, value in self.coreografy.items():
            print("Dance has " + str(key))

    def get_coreografy_move_image(self):
        img = cv2.imread("coreografy/move_" + str(self.current_move)+ ".jpg")
        rotated_img  = np.rot90(img)
        result_frame = cv2.cvtColor(rotated_img, cv2.COLOR_BGR2RGB)
        surf = pygame.surfarray.make_surface(result_frame)
        return surf
    
    def distance(self, p1, p2):
        distance = ((p1["x"] - p2["x"])**2 + (p1["y"] - p2["y"])**2)**(0.5)
        return distance
    
    def get_current_move(self):
        return self.coreografy["move_" + str(self.current_move)]["pose"]

    def calculate_player_score(self, player_pose):
        if not player_pose:
            return 0
        move = self.get_current_move()
        # Only upper body. Webcam doesn't have enogh FoV and the room is kinda short :(
        nose_dist = self.distance(player_pose["nose"], move["nose"])
        l_sholder_dist = self.distance(player_pose["left_shoulder"],move["left_shoulder"])
        r_sholder_dist = self.distance(player_pose["right_shoulder"],move["right_shoulder"])
        l_elbow_dist = self.distance(player_pose["left_elbow"],move["left_elbow"])
        r_elbow_dist = self.distance(player_pose["right_elbow"],move["right_elbow"])
        l_elbow_dist = self.distance(player_pose["right_elbow"],move["right_elbow"])
        l_wrist_dist = self.distance(player_pose["left_wrist"],move["left_wrist"])
        r_wrist_dist = self.distance(player_pose["right_wrist"],move["right_wrist"])

        # 0 distance = 100 score points
        score = (100/(nose_dist + 1) 
            + 100/(l_sholder_dist + 1) 
            + 100/(r_sholder_dist + 1) 
            + 100/(l_elbow_dist + 1)
            + 100/(r_elbow_dist + 1) 
            + 100/(l_wrist_dist + 1)
            + 100/(r_wrist_dist + 1)) / 7.0

        return round(score)
    