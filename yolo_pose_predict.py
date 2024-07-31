from ultralytics import YOLO

model = YOLO('yolov8m-pose.pt')

results = model(source=0, show=True, conf=0.3)
