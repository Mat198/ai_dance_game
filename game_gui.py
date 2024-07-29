import sys
import pygame
from pygame.locals import *
from pygame import mixer 

from  camera import Camera
from coreografy import Coreografy

# Init pygame engine
pygame.init() # screen
mixer.init() # sound
pygame.font.init() # text
game_font = pygame.font.SysFont('Comic Sans MS', 30)

# Loading the song 
mixer.music.load("Los Del Rio - Macarena (Bayside Boys Remix).mp3") 
  
# Setting the volume 
mixer.music.set_volume(0.7) 

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
SCREEN_HEIGHT = 480
display = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
display.fill(WHITE)
pygame.display.set_caption("Let's Dance!")

game_camera = Camera(); 
running = False

# Initial game screen
start_text = game_font.render("Let's Dance! Click to start!", False, (0, 0, 0))

dance = Coreografy()
dance.load_coreografy()

mixer.music.play()
mixer.music.pause() 

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
            # Start playing the song dance
            running = True
            dance.start_coreografy()
            mixer.music.unpause() 
    
    # Updates camera frame 
    success = game_camera.update()
    if not success:
        pygame.quit()
        sys.exit()

    # Gets the detections
    detections = game_camera.get_detection()

    # Display current image
    display.blit(game_camera.get_frame(), (0, 0))
    
    # Show coreografy on screen
    if running:
        display.blit(dance.get_coreografy_move_image(), (640, 0))
        dance.update_dance(detections)
    
    # Game start text
    if not running:
        display.blit(start_text, (480,240))
        
    score_text = game_font.render("Score: " + dance.get_score(), False, (0, 0, 0))
    display.blit(score_text, (0,0))

    # Check for game end
    if running and not pygame.mixer.music.get_busy():
        running = False
        print("Song is finshed")

    # Update the camera screen
    pygame.display.update()
    fps_clock.tick(FPS_VALUE)
