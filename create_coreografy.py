import os
import cv2
import time
import json
from ultralytics import YOLO
from keypoints import get_xy_keypoint, Point

model = YOLO('yolov8m-pose.pt')

# Set camera as webcam
cam = cv2.VideoCapture(0)


cv2.namedWindow("LetsDance!")

start_time = time.time()

font = cv2.FONT_HERSHEY_SIMPLEX
count = 0

# Create folder to save choreography
folder = r'choreography' 
if not os.path.exists(folder):
    os.makedirs(folder)

# Setup the dance file
dance = {}

while True:
    ret, frame = cam.read()
    if not ret:
        print("failed to grab frame")
        break

    results = model(source=frame, conf=0.3, show=False, verbose=False, stream=False)

    keypoints = get_xy_keypoint(results[0])

    current_time = time.time() - start_time

    display_time = str(round(current_time))
    save = False
    # Add image every 5 seconds
    if current_time >= 5.0:
        cv2.imwrite(os.path.join(folder, "move_" + str(count) + ".jpg"), frame)
        start_time = time.time()
        display_time = "POSE SAVED!"
        save = True

    if keypoints:
        if save:
            dance["move_" + str(count)] = {"time": 0.0, "pose": keypoints}
            count += 1
        
        for key, value in keypoints.items():
            # print(key, ": ", value.x, ", ", value.y)
            frame = cv2.circle(frame, (value["x"],  value["y"]), 2, color=(0, 0, 255), thickness=-1)
            frame = cv2.putText(frame, display_time, (10,450), font, 3, (0, 255, 0), 2, cv2.LINE_AA)

    cv2.imshow("LetsDance!", frame)

    key = cv2.waitKey(1)
    # ESC pressed
    if key%256 == 27:
        print("Escape hit, closing...")
        break

with open(os.path.join('choreography',"dance.json"), "a") as file:
    json.dump(dance, file)
    
# Free camera resources
cam.release()
cv2.destroyAllWindows()