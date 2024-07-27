import cv2
from ultralytics import YOLO
from keypoints import get_xy_keypoint, Point

model = YOLO('yolov8m-pose.pt')

# Set camera as webcam
cam = cv2.VideoCapture(0)

cv2.namedWindow("LetsDance!")

img_counter = 0

while True:
    ret, frame = cam.read()
    if not ret:
        print("failed to grab frame")
        break

    results = model(source=frame, conf=0.3, show=True)

    keypoints = get_xy_keypoint(results[0])

    for key, value in keypoints.items():
        print(key, ": (", value.x, ", ", value.y)
        frame = cv2.circle(frame, (int(value.x),  int(value.y)), 2, color=(0, 0, 255), thickness=-1)

    # Criar o modo de adquirir as posturar para comparar
    # Criar método de comparar a postura atual com a do jogo
    # Mostrar pontuação na tela
    # Subir no Git com vídeo
    # Postar no Linkedinho
    cv2.imshow("LetsDance!", frame)

    key = cv2.waitKey(1)
    # ESC pressed
    if key%256 == 27:
        print("Escape hit, closing...")
        break
    
# Free camera resources
cam.release()
cv2.destroyAllWindows()