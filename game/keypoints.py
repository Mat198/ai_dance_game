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


def _center_x(pose: dict) -> float:
    """Horizontal centre of a pose, for ordering players left-to-right. Prefers the
    shoulders, then the nose, then the mean of all detected joints."""
    def used(name):
        v = pose.get(name)
        return v if v and not (v["x"] == 0 and v["y"] == 0) else None
    shoulders = [used("left_shoulder"), used("right_shoulder")]
    shoulders = [v for v in shoulders if v]
    if shoulders:
        return sum(v["x"] for v in shoulders) / len(shoulders)
    nose = used("nose")
    if nose:
        return nose["x"]
    xs = [v["x"] for v in pose.values() if not (v["x"] == 0 and v["y"] == 0)]
    return sum(xs) / len(xs) if xs else 0.0


def get_players_keypoints(results: Results, max_players: int = 2) -> list:
    """Extract up to `max_players` people from a frame, ordered left-to-right by
    their horizontal position in the image. Returns a list of keypoint dicts."""
    kp = results.keypoints
    if kp is None:
        return []
    xy_all = kp.xy.cpu().numpy()
    if len(xy_all) == 0:
        return []
    conf_all = kp.conf.cpu().numpy() if kp.conf is not None else None
    players = []
    for i in range(len(xy_all)):
        if len(xy_all[i]) == 0:
            continue
        conf = conf_all[i] if conf_all is not None else None
        players.append(extract_keypoint(xy_all[i], conf))
    players.sort(key=_center_x)
    return players[:max_players]
