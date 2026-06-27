"""Headless pose-detection service for the Godot front-end.

Captures the webcam, runs YOLOv8-pose inference, extracts named keypoints and
publishes them as JSON datagrams over UDP. It holds no game state: move timing
and scoring live in the Godot client. This decoupling exists because Godot's
CameraServer has no Linux/Windows desktop backend, so webcam capture must stay
in Python.

Protocol (one UDP datagram per processed frame, "latest packet wins"):
    {
      "frame": <int>,                 # monotonically increasing frame counter
      "width": <int>, "height": <int>,# source frame size, for coordinate mapping
      "keypoints": { "nose": {"x": int, "y": int}, ... } | null
    }
`keypoints` is null when no player is detected.

Run (from the repository root, with the virtualenv active):
    python -m ai_camera_server.vision_service --host 127.0.0.1 --port 5005 --camera 0
"""

import argparse
import json
import socket

import cv2
from ultralytics import YOLO

from game.keypoints import get_xy_keypoint

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 5005
DEFAULT_CAMERA = 0
DEFAULT_CONF = 0.6
DEFAULT_WEIGHTS = "weights/yolov8m-pose.pt"


def parse_args():
    parser = argparse.ArgumentParser(description="AI Dance Game pose-detection service")
    parser.add_argument("--host", default=DEFAULT_HOST, help="UDP destination host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="UDP destination port")
    parser.add_argument("--camera", type=int, default=DEFAULT_CAMERA, help="OpenCV camera index")
    parser.add_argument("--conf", type=float, default=DEFAULT_CONF, help="YOLO confidence threshold")
    parser.add_argument("--weights", default=DEFAULT_WEIGHTS, help="Path to YOLO pose weights")
    parser.add_argument("--show", action="store_true", help="Show an annotated preview window (debug)")
    return parser.parse_args()


def main():
    args = parse_args()

    print(f"Loading pose model from {args.weights} ...")
    model = YOLO(args.weights)

    # Prefer the V4L2 backend on Linux for resolution/format control, falling back
    # to the default backend if it isn't available.
    cam = cv2.VideoCapture(args.camera, cv2.CAP_V4L2)
    if not cam.isOpened():
        cam = cv2.VideoCapture(args.camera)
    if not cam.isOpened():
        raise SystemExit(f"Could not open camera index {args.camera}")

    # Request the best resolution/format the webcam supports. FOURCC must be an
    # integer code, not the raw string, or the format request is silently ignored.
    cam.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
    cam.set(cv2.CAP_PROP_FPS, 30)
    cam.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cam.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    dest = (args.host, args.port)
    print(f"Streaming keypoints to udp://{args.host}:{args.port}  (Ctrl+C to stop)")

    frame_index = 0
    try:
        while True:
            ret, frame = cam.read()
            if not ret:
                print("Failed to get camera frame")
                break

            height, width = frame.shape[:2]

            # stream=True returns a generator; conf filters low-confidence detections.
            results = model(source=frame, conf=args.conf, stream=True, verbose=False)

            keypoints = None
            annotated = frame
            for detection in results:
                keypoints = get_xy_keypoint(detection)
                if args.show:
                    annotated = detection.plot()

            payload = {
                "frame": frame_index,
                "width": int(width),
                "height": int(height),
                "keypoints": keypoints,
            }
            sock.sendto(json.dumps(payload).encode("utf-8"), dest)
            frame_index += 1

            if args.show:
                cv2.imshow("vision_service (debug)", annotated)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
    except KeyboardInterrupt:
        print("\nStopping vision service.")
    finally:
        cam.release()
        sock.close()
        if args.show:
            cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
