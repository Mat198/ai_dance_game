import pygame
from pygame.locals import *
from game.keypoints import get_xy_keypoint, BODY_PARTS
import numpy as np
import cv2
from cv2.typing import MatLike

class Player():
    
    def __init__(self):
        self.keypoints = {}
 
    def update(self, keypoints):
        self.keypoints = get_xy_keypoint()

    def add_player_to_frame(self, frame: MatLike, keypoints: list) -> MatLike:
        for part in BODY_PARTS:
            frame = self.add_body_point(frame, keypoints[part])
        frame = self.add_body_line(frame, keypoints["nose"], keypoints["left_shoulder"])
        frame = self.add_body_line(frame, keypoints["nose"], keypoints["right_shoulder"])
        frame = self.add_body_line(frame, keypoints["left_shoulder"], keypoints["left_elbow"])
        frame = self.add_body_line(frame, keypoints["right_shoulder"], keypoints["right_elbow"])
        frame = self.add_body_line(frame, keypoints["left_elbow"], keypoints["left_wrist"])
        frame = self.add_body_line(frame, keypoints["right_elbow"], keypoints["right_wrist"])
        return frame
        
    def convert_frame_to_surface(frame: MatLike) -> pygame.SurfaceType:
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