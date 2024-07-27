import pygame, sys
from pygame.locals import *
from keypoints import get_xy_keypoint

class Player():
    def __init__(self):
        self.keypoints = {}
 
    def update(self, keypoints):
        self.keypoints = get_xy_keypoint()
 