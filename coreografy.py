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
        self.body_parts = (
            "nose", "left_shoulder", "right_shoulder", 
            "left_elbow", "right_elbow" , "left_wrist","right_wrist"
        )
 
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
        frame = cv2.imread("coreografy/move_" + str(self.current_move)+ ".jpg")
        # Plot pose keypoints
        keypoints = self.get_current_move()
        
        for part in self.body_parts:
            frame = self.add_body_point(frame, keypoints[part])

        frame = self.add_body_line(frame, keypoints["nose"], keypoints["left_shoulder"])
        frame = self.add_body_line(frame, keypoints["nose"], keypoints["right_shoulder"])
        frame = self.add_body_line(frame, keypoints["left_shoulder"], keypoints["left_elbow"])
        frame = self.add_body_line(frame, keypoints["right_shoulder"], keypoints["right_elbow"])
        frame = self.add_body_line(frame, keypoints["left_elbow"], keypoints["left_wrist"])
        frame = self.add_body_line(frame, keypoints["right_elbow"], keypoints["right_wrist"])
        
        frame = np.rot90(frame)
        result_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        surf = pygame.surfarray.make_surface(result_frame)
        return surf

    def get_coordinate(self, body_part):
        return (body_part["x"], body_part["y"])
    
    def add_body_point(self, frame, body_part):
        frame = cv2.circle(
            frame, 
            self.get_coordinate(body_part), 
            3, color=(0, 0, 255), thickness=2
        )
        return frame

    def add_body_line(self, frame, part1, part2):
        frame = cv2.line(
            frame, 
            self.get_coordinate(part1), self.get_coordinate(part2), 
            (0, 255, 0), thickness=2
        )
        return frame
    
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
        score = 0
        for part in self.body_parts:
            distance = self.distance(player_pose[part], move[part])
            # 0 distance = 100 score points
            score += 100/(distance + 1) 

        score = score / len(self.body_parts)
   
        return round(score)
    