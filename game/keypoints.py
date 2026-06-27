import numpy as np
from game.geometry import Point  # re-exported; imported by camera.py / create_choreography.py

from ultralytics.engine.results import Results

# COCO-17 keypoint order produced by YOLOv8-pose.
# Got from: https://github.com/Alimustoofaa/YoloV8-Pose-Keypoint-Classification/blob/master/src/detection_keypoint.py
KEYPOINT_NAMES = [
    "nose", "left_eye", "right_eye", "left_ear", "right_ear",
    "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
    "left_wrist", "right_wrist", "left_hip", "right_hip",
    "left_knee", "right_knee", "left_ankle", "right_ankle",
]


def extract_keypoint(xy: np.ndarray, conf: np.ndarray = None) -> dict:
    """Map the 17 (x, y) keypoints (and optional per-keypoint confidence) to a
    named dictionary: {"nose": {"x": int, "y": int, "c": float}, ...}.

    `c` is the detection confidence in [0, 1] and lets consumers hide joints the
    model only guessed at (e.g. legs out of the camera frame). It is omitted when
    confidence isn't available.
    """
    keypoints = {}
    for i, name in enumerate(KEYPOINT_NAMES):
        x, y = xy[i]
        entry = {"x": int(x), "y": int(y)}
        if conf is not None:
            entry["c"] = round(float(conf[i]), 3)
        keypoints[name] = entry
    return keypoints


def get_xy_keypoint(results: Results) -> dict:
    kp = results.keypoints
    xy_all = kp.xy.cpu().numpy()
    if len(xy_all) == 0:
        return None
    xy = xy_all[0]
    if len(xy) == 0:
        return None
    conf = None
    if kp.conf is not None:
        conf = kp.conf.cpu().numpy()[0]
    return extract_keypoint(xy, conf)
