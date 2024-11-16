import numpy as np
from game.geometry import Point

from ultralytics.engine.results import Results

# Got from: https://github.com/Alimustoofaa/YoloV8-Pose-Keypoint-Classification/blob/master/src/detection_keypoint.py

NOSE:           int = 0
LEFT_EYE:       int = 1
RIGHT_EYE:      int = 2
LEFT_EAR:       int = 3
RIGHT_EAR:      int = 4
LEFT_SHOULDER:  int = 5
RIGHT_SHOULDER: int = 6
LEFT_ELBOW:     int = 7
RIGHT_ELBOW:    int = 8
LEFT_WRIST:     int = 9
RIGHT_WRIST:    int = 10
LEFT_HIP:       int = 11
RIGHT_HIP:      int = 12
LEFT_KNEE:      int = 13
RIGHT_KNEE:     int = 14
LEFT_ANKLE:     int = 15
RIGHT_ANKLE:    int = 16

def extract_keypoint(keypoint: np.ndarray) -> dict[str, Point]:
    # nose
    nose_x, nose_y = keypoint[NOSE]
    # eye
    left_eye_x, left_eye_y = keypoint[LEFT_EYE]
    right_eye_x, right_eye_y = keypoint[RIGHT_EYE]
    # ear
    left_ear_x, left_ear_y = keypoint[LEFT_EAR]
    right_ear_x, right_ear_y = keypoint[RIGHT_EAR]
    # shoulder
    left_shoulder_x, left_shoulder_y = keypoint[LEFT_SHOULDER]
    right_shoulder_x, right_shoulder_y = keypoint[RIGHT_SHOULDER]
    # elbow
    left_elbow_x, left_elbow_y = keypoint[LEFT_ELBOW]
    right_elbow_x, right_elbow_y = keypoint[RIGHT_ELBOW]
    # wrist
    left_wrist_x, left_wrist_y = keypoint[LEFT_WRIST]
    right_wrist_x, right_wrist_y = keypoint[RIGHT_WRIST]
    # hip
    left_hip_x, left_hip_y = keypoint[LEFT_HIP]
    right_hip_x, right_hip_y = keypoint[RIGHT_HIP]
    # knee
    left_knee_x, left_knee_y = keypoint[LEFT_KNEE]
    right_knee_x, right_knee_y = keypoint[RIGHT_KNEE]
    # ankle
    left_ankle_x, left_ankle_y = keypoint[LEFT_ANKLE]
    right_ankle_x, right_ankle_y = keypoint[RIGHT_ANKLE]
    
    # Dictionary with the keypoint for meaningfull access.
    keypoints = {
        "nose": {"x":int(nose_x), "y": int(nose_y)}, 
        "left_eye": {"x":int(left_eye_x), "y": int(left_eye_y)},
        "right_eye": {"x":int(right_eye_x), "y": int(right_eye_y)},
        "left_ear": {"x":int(left_ear_x), "y": int(left_ear_y)},
        "right_ear": {"x":int(right_ear_x), "y": int(right_ear_y)},
        "left_shoulder": {"x":int(left_shoulder_x), "y": int(left_shoulder_y)},
        "right_shoulder": {"x":int(right_shoulder_x), "y": int(right_shoulder_y)},
        "left_elbow": {"x":int(left_elbow_x), "y": int(left_elbow_y)},
        "right_elbow": {"x":int(right_elbow_x), "y": int(right_elbow_y)},
        "left_wrist": {"x":int(left_wrist_x), "y": int(left_wrist_y)},
        "right_wrist": {"x":int(right_wrist_x), "y": int(right_wrist_y)},
        "left_hip": {"x":int(left_hip_x), "y": int(left_hip_y)},
        "right_hip": {"x":int(right_hip_x), "y":int(right_hip_y)},
        "left_knee": {"x":int(left_knee_x), "y":int(left_knee_y)},
        "right_knee": {"x":int(right_knee_x), "y":int(right_knee_y)},
        "left_ankle": {"x":int(left_ankle_x), "y": int(left_ankle_y)},
        "right_ankle": {"x":int(right_ankle_x), "y": int(right_ankle_y)}
    }
    return keypoints


def get_xy_keypoint(results: Results) -> dict[str, Point]:
    if len(results.keypoints.xy.cpu().numpy()) == 0:
        return None
    result_keypoint = results.keypoints.xy.cpu().numpy()[0]
    if len(result_keypoint) == 0:
        return None
    keypoint_data = extract_keypoint(result_keypoint)
    return keypoint_data