"""Build the choreography (dance.json) from a folder of reference photos.

This lets the reference images stay OUT of the repository: keep your photos in a
local folder (e.g. pose_sources/, which is gitignored), run this script, and only
the extracted keypoints in choreography/dance.json get committed. The game renders
the reference poses as skeletons from that JSON, so the photos are never needed at
runtime.

Images are processed in natural filename order. Each image becomes move_1, move_2,
... with a cumulative `time` of (n * --interval) seconds.

Run:
    python extract_poses.py --images pose_sources --interval 3.0
"""

import argparse
import json
import os
import re

import cv2
from ultralytics import YOLO

from game.keypoints import get_xy_keypoint

DEFAULT_IMAGES = "pose_sources"
DEFAULT_OUTPUT = "choreography/dance.json"
DEFAULT_WEIGHTS = "weights/yolov8m-pose.pt"
DEFAULT_INTERVAL = 3.0
DEFAULT_CONF = 0.3
IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".bmp")


def natural_key(name):
    # Sort "move_2.jpg" before "move_10.jpg".
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", name)]


def parse_args():
    parser = argparse.ArgumentParser(description="Extract choreography poses from images")
    parser.add_argument("--images", default=DEFAULT_IMAGES, help="Folder of reference photos")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="Output dance JSON path")
    parser.add_argument("--weights", default=DEFAULT_WEIGHTS, help="Path to YOLO pose weights")
    parser.add_argument("--interval", type=float, default=DEFAULT_INTERVAL,
                        help="Seconds between consecutive moves")
    parser.add_argument("--conf", type=float, default=DEFAULT_CONF, help="YOLO confidence threshold")
    return parser.parse_args()


def main():
    args = parse_args()

    if not os.path.isdir(args.images):
        raise SystemExit(f"Images folder not found: {args.images}")

    files = sorted(
        (f for f in os.listdir(args.images) if f.lower().endswith(IMAGE_EXTS)),
        key=natural_key,
    )
    if not files:
        raise SystemExit(f"No images found in {args.images}")

    print(f"Loading pose model from {args.weights} ...")
    model = YOLO(args.weights)

    dance = {}
    move_number = 0
    for filename in files:
        path = os.path.join(args.images, filename)
        frame = cv2.imread(path)
        if frame is None:
            print(f"  skip (unreadable): {filename}")
            continue

        results = model(source=frame, conf=args.conf, verbose=False)
        keypoints = get_xy_keypoint(results[0]) if results else None
        if not keypoints:
            print(f"  skip (no pose detected): {filename}")
            continue

        move_number += 1
        dance[f"move_{move_number}"] = {
            "time": round(move_number * args.interval, 3),
            "pose": keypoints,
        }
        print(f"  move_{move_number} <- {filename}")

    if not dance:
        raise SystemExit("No poses extracted; dance.json was not written.")

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w") as f:
        json.dump(dance, f, indent=2)
    print(f"Wrote {len(dance)} moves to {args.output}")


if __name__ == "__main__":
    main()
