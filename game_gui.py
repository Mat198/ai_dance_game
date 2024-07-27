import sys
import pygame
from pygame.locals import *

from  camera import Camera
from player import Player

# Init pygame engine
pygame.init()

# Predefined some colors
BLUE  = (0, 0, 255)
RED   = (255, 0, 0)
GREEN = (0, 255, 0)
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)

# Defining game FPS 
FPS_VALUE = 60
fps_clock = pygame.time.Clock()

# Defining screen propertys
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
display = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
display.fill(WHITE)
pygame.display.set_caption("Let's Dance!")

game_camera = Camera(); 
running = False

def game_start():
    
    running = True

#Game loop begins
while True:
    # Verify for game close
    events = pygame.event.get()
    for event in events:
        if event.type == QUIT:
            pygame.quit()
            sys.exit()

        # Game starts on click
        if (not running)and (event.type == pygame.MOUSEBUTTONDOWN):
            print('Started game!')
            running = True

    # Updates camera frame 
    success = game_camera.update()
    if not success:
        pygame.quit()
        sys.exit()

    # Gets the detections
    detections = game_camera.get_detection()

    # Display current image
    display.blit(game_camera.get_frame(), (0, 0))

   

    # Update the camera screen
    pygame.display.update()
    fps_clock.tick(FPS_VALUE)
