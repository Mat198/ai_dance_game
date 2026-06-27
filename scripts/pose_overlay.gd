class_name PoseOverlay
extends Node2D
## Draws two skeletons on top of the gameplay scene:
##   - left panel:  the live player pose (mirrored, selfie-style) from VisionClient
##   - right panel: the reference pose for the current move, drawn from dance.json
##
## The reference is rendered purely from the stored keypoints (no photo), so no
## personal reference images need to live in the repo. The pose coordinates were
## captured at 640x480, which is exactly the panel size, so they map 1:1.

const PANEL_W := 640.0
const PANEL_H := 480.0
# Resolution the reference poses were captured at (see create_coreografy.py).
const REF_W := 640.0
const REF_H := 480.0

const PLAYER_BG := Color(0.10, 0.12, 0.18)
const REF_BG := Color(0.12, 0.10, 0.16)

const BONES := [
	# head
	["left_ear", "left_eye"], ["left_eye", "nose"],
	["nose", "right_eye"], ["right_eye", "right_ear"],
	# arms
	["left_wrist", "left_elbow"], ["left_elbow", "left_shoulder"],
	["right_wrist", "right_elbow"], ["right_elbow", "right_shoulder"],
	# shoulders + torso
	["left_shoulder", "right_shoulder"],
	["left_shoulder", "left_hip"], ["right_shoulder", "right_hip"],
	["left_hip", "right_hip"],
	# legs
	["left_hip", "left_knee"], ["left_knee", "left_ankle"],
	["right_hip", "right_knee"], ["right_knee", "right_ankle"],
]
const PARTS := [
	"nose", "left_eye", "right_eye", "left_ear", "right_ear",
	"left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
	"left_wrist", "right_wrist", "left_hip", "right_hip",
	"left_knee", "right_knee", "left_ankle", "right_ankle",
]

var choreo: Choreography
var current_index := 0

func _draw() -> void:
	draw_rect(Rect2(0, 0, PANEL_W, PANEL_H), PLAYER_BG)
	draw_rect(Rect2(PANEL_W, 0, PANEL_W, PANEL_H), REF_BG)
	draw_line(Vector2(PANEL_W, 0), Vector2(PANEL_W, PANEL_H), Color(1, 1, 1, 0.25), 2.0)
	_draw_player()
	_draw_reference()

func _draw_player() -> void:
	var kp = VisionClient.keypoints
	if kp == null:
		return
	var sw := float(VisionClient.source_width)
	var sh := float(VisionClient.source_height)
	if sw <= 0.0 or sh <= 0.0:
		return
	var to_panel := func(p):
		# Mirror horizontally so it reads like a mirror, map into the left panel.
		var x := PANEL_W - (float(p["x"]) / sw * PANEL_W)
		var y := float(p["y"]) / sh * PANEL_H
		return Vector2(x, y)
	_draw_skeleton(kp, to_panel, Color(0.2, 0.8, 1.0), Color(1, 1, 1))

func _draw_reference() -> void:
	if choreo == null:
		return
	var pose := choreo.reference_pose(current_index)
	var to_panel := func(p):
		var x := PANEL_W + (float(p["x"]) / REF_W * PANEL_W)
		var y := float(p["y"]) / REF_H * PANEL_H
		return Vector2(x, y)
	_draw_skeleton(pose, to_panel, Color(0.2, 1.0, 0.4), Color(0.9, 0.9, 0.3))

func _draw_skeleton(pose: Dictionary, to_panel: Callable, line_color: Color, point_color: Color) -> void:
	for bone in BONES:
		if _valid(pose, bone[0]) and _valid(pose, bone[1]):
			draw_line(to_panel.call(pose[bone[0]]), to_panel.call(pose[bone[1]]), line_color, 3.0)
	for part in PARTS:
		if _valid(pose, part):
			draw_circle(to_panel.call(pose[part]), 5.0, point_color)

## A keypoint is "valid" if present and not at the origin (YOLO reports (0,0)
## for joints it couldn't detect, e.g. legs out of webcam frame).
func _valid(pose: Dictionary, part: String) -> bool:
	if not pose.has(part):
		return false
	var p = pose[part]
	return not (int(p["x"]) == 0 and int(p["y"]) == 0)
