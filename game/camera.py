import cv2
from ultralytics import YOLO
import pygame
import numpy as np
from game.keypoints import get_xy_keypoint, Point

YOLO_MODEL = YOLO('weights/yolov8m-pose.pt')

class Camera():
    # Constructor
    def __init__(self):
        # Set camera as webcam
        self.cam = cv2.VideoCapture(0)
        # self.cam.set(cv2.CAP_PROP_FRAME_WIDTH, 10000)
        # self.cam.set(cv2.CAP_PROP_FRAME_HEIGHT, 10000)
        self.frame = None
        self.detections = None
    
    # Destructor
    def __del__(self):
        self.cam.release()

    def update(self):
        ret, self.frame = self.cam.read()
        if not ret:
            print("Failed to get camera frame")
            return False

        results = YOLO_MODEL(source=self.frame, conf=0.6, stream=True, verbose=False)

        if not results:
            print("No players found on camera!")
            return False
        
        for detection in results:
            self.detections = get_xy_keypoint(detection)
            self.frame = detection.plot()

        return True

    def get_detection(self):
        return self.detections
    
    def get_frame(self):
        # For some reasons the frames appeared inverted
        converted_frame = np.fliplr(self.frame)
        converted_frame  = np.rot90(self.frame)

        # The video uses BGR colors and PyGame needs RGB
        result_frame = cv2.cvtColor(converted_frame, cv2.COLOR_BGR2RGB)

        surf = pygame.surfarray.make_surface(result_frame)
        return surf