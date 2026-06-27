class_name PoseOverlay
extends Node2D
## Draws two stacked skeletons:
##   - top panel:    the live player pose (mirrored, selfie-style) from VisionClient
##   - bottom panel: the reference pose for the current move, from dance.json
##
## Each pose is fit into its panel with a uniform scale (preserving aspect ratio)
## and centred, so changing the webcam resolution never distorts the figure.

const PANEL_W := 1280.0
const PANEL_H := 720.0
# Resolution the reference poses were captured at (see create_choreography.py).
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
	var player_rect := Rect2(0, 0, PANEL_W, PANEL_H)
	var ref_rect := Rect2(0, PANEL_H, PANEL_W, PANEL_H)
	draw_rect(player_rect, PLAYER_BG)
	draw_rect(ref_rect, REF_BG)
	draw_line(Vector2(0, PANEL_H), Vector2(PANEL_W, PANEL_H), Color(1, 1, 1, 0.25), 2.0)
	_draw_player(player_rect)
	_draw_reference(ref_rect)

func _draw_player(rect: Rect2) -> void:
	var kp = VisionClient.keypoints
	if kp == null:
		return
	var sw := float(VisionClient.source_width)
	var sh := float(VisionClient.source_height)
	if sw <= 0.0 or sh <= 0.0:
		return
	# Mirror horizontally so it reads like a mirror.
	var mapper := _make_mapper(sw, sh, rect, true)
	_draw_skeleton(kp, mapper, Color(0.2, 0.8, 1.0), Color(1, 1, 1))

func _draw_reference(rect: Rect2) -> void:
	if choreo == null:
		return
	var pose := choreo.reference_pose(current_index)
	var mapper := _make_mapper(REF_W, REF_H, rect, false)
	_draw_skeleton(pose, mapper, Color(0.2, 1.0, 0.4), Color(0.9, 0.9, 0.3))

## Returns a Callable that maps a {"x","y"} keypoint in native (nw x nh) coordinates
## into `rect`, scaled uniformly and centred, optionally mirrored horizontally.
func _make_mapper(nw: float, nh: float, rect: Rect2, mirror: bool) -> Callable:
	var fit_scale := minf(rect.size.x / nw, rect.size.y / nh)
	var draw_w := nw * fit_scale
	var draw_h := nh * fit_scale
	var off_x := rect.position.x + (rect.size.x - draw_w) * 0.5
	var off_y := rect.position.y + (rect.size.y - draw_h) * 0.5
	return func(p):
		var x := float(p["x"]) * fit_scale
		if mirror:
			x = draw_w - x
		return Vector2(off_x + x, off_y + float(p["y"]) * fit_scale)

func _draw_skeleton(pose: Dictionary, mapper: Callable, line_color: Color, point_color: Color) -> void:
	for bone in BONES:
		if _valid(pose, bone[0]) and _valid(pose, bone[1]):
			draw_line(mapper.call(pose[bone[0]]), mapper.call(pose[bone[1]]), line_color, 3.0)
	for part in PARTS:
		if _valid(pose, part):
			draw_circle(mapper.call(pose[part]), 5.0, point_color)

## A keypoint is "valid" if present and not at the origin (YOLO reports (0,0)
## for joints it couldn't detect, e.g. legs out of webcam frame).
func _valid(pose: Dictionary, part: String) -> bool:
	if not pose.has(part):
		return false
	var p = pose[part]
	return not (int(p["x"]) == 0 and int(p["y"]) == 0)
