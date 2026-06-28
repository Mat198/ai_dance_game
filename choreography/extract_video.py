"""Build a choreography timeline (dance.csv) from a dance video.

Runs YOLOv8-pose over the video frames, downsamples to a target fps, smooths the
keypoints, and writes a CSV timeline the game plays back and interpolates. Keep the
video itself out of the repo (e.g. in a gitignored folder); only dance.csv ships.

Record to the same song you play in-game so the timeline lines up with the music.

CSV layout:
    # fps=15.00 width=1280 height=720          <- metadata comment
    nose_x,nose_y,nose_c, ... ,right_ankle_c   <- column header (one row per frame)
    330,184,0.95, ... ,0.05
    ...
Time of a row = row_index / fps.

Run (from the repository root, with the virtualenv active):
    python -m choreography.extract_video --video pose_sources/dance.mp4 --fps 15
"""

import argparse
import csv
import os

import cv2
from ultralytics import YOLO

from game.keypoints import get_xy_keypoint, KEYPOINT_NAMES

DEFAULT_OUTPUT = "choreography/dance.csv"
DEFAULT_WEIGHTS = "weights/yolov8m-pose.pt"
DEFAULT_FPS = 15.0
DEFAULT_CONF = 0.3
DEFAULT_SMOOTH = 5  # moving-average window (frames); 1 disables smoothing


def parse_args():
    p = argparse.ArgumentParser(description="Extract a choreography timeline from a dance video")
    p.add_argument("--video", required=True, help="Path to the input dance video")
    p.add_argument("--output", default=DEFAULT_OUTPUT, help="Output CSV timeline path")
    p.add_argument("--weights", default=DEFAULT_WEIGHTS, help="Path to YOLO pose weights")
    p.add_argument("--fps", type=float, default=DEFAULT_FPS, help="Target timeline frames per second")
    p.add_argument("--conf", type=float, default=DEFAULT_CONF, help="YOLO confidence threshold")
    p.add_argument("--smooth", type=int, default=DEFAULT_SMOOTH, help="Moving-average window in frames")
    p.add_argument("--song", default="", help="Song res:// path to record in the timeline (e.g. res://songs/foo.mp3)")
    return p.parse_args()


def smooth_frames(frames, window):
    """Centered moving average over x/y/c per keypoint to de-jitter the timeline."""
    if window <= 1 or len(frames) < 2:
        return frames
    half = window // 2
    n = len(frames)
    out = []
    for i in range(n):
        lo = max(0, i - half)
        hi = min(n, i + half + 1)
        window_frames = frames[lo:hi]
        pose = {}
        for name in KEYPOINT_NAMES:
            xs = [f[name]["x"] for f in window_frames]
            ys = [f[name]["y"] for f in window_frames]
            cs = [f[name]["c"] for f in window_frames]
            pose[name] = {
                "x": int(round(sum(xs) / len(xs))),
                "y": int(round(sum(ys) / len(ys))),
                "c": round(sum(cs) / len(cs), 3),
            }
        out.append(pose)
    return out


def write_csv(path, fps, width, height, frames, song=""):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", newline="") as fh:
        fh.write(f"# fps={fps:.2f} width={width} height={height}\n")
        if song:
            fh.write(f"# song={song}\n")
        writer = csv.writer(fh)
        header = []
        for name in KEYPOINT_NAMES:
            header += [f"{name}_x", f"{name}_y", f"{name}_c"]
        writer.writerow(header)
        for pose in frames:
            row = []
            for name in KEYPOINT_NAMES:
                kp = pose[name]
                row += [kp["x"], kp["y"], kp["c"]]
            writer.writerow(row)


def main():
    args = parse_args()
    if not os.path.isfile(args.video):
        raise SystemExit(f"Video not found: {args.video}")

    cap = cv2.VideoCapture(args.video)
    if not cap.isOpened():
        raise SystemExit(f"Could not open video: {args.video}")
    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    step = max(1, round(src_fps / args.fps))
    out_fps = src_fps / step

    print(f"Loading pose model from {args.weights} ...")
    model = YOLO(args.weights)

    frames = []
    width = 0
    height = 0
    last_pose = None
    index = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        if index % step == 0:
            height, width = frame.shape[:2]
            results = model(source=frame, conf=args.conf, verbose=False)
            pose = get_xy_keypoint(results[0]) if results else None
            # Carry the previous pose forward over brief detection gaps so the
            # timeline stays continuous; skip until the first detection.
            if pose is None:
                pose = last_pose
            if pose is not None:
                frames.append(pose)
                last_pose = pose
        index += 1
    cap.release()

    if not frames:
        raise SystemExit("No poses detected in the video; nothing written.")

    frames = smooth_frames(frames, args.smooth)
    write_csv(args.output, out_fps, width, height, frames, args.song)
    print(f"Wrote {len(frames)} frames @ {out_fps:.2f} fps ({width}x{height}) to {args.output}")


if __name__ == "__main__":
    main()
