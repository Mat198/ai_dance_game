class_name PoseOverlay
extends Node2D
## Draws two stacked stick figures:
##   - top panel:    the live player pose (mirrored, selfie-style) from VisionClient
##   - bottom panel: the reference pose for the current move, from dance.json
##
## Each figure is a circular head (sized from the ear-to-ear distance) plus capsule
## limbs (thick segments with rounded joint caps). Poses are fit into their panel
## with a uniform scale (preserving aspect ratio), so the webcam resolution and the
## reference resolution can differ without distorting the figure.

const PANEL_W := 1280.0
const PANEL_H := 720.0
# Resolution the reference poses were captured at (see create_choreography.py).
const REF_W := 640.0
const REF_H := 480.0

# Joints below this detection confidence are hidden (e.g. legs out of frame, which
# YOLO still guesses at a low-confidence random position).
const CONF_THRESHOLD := 0.5

const PLAYER_BG := Color(0.10, 0.12, 0.18)
const REF_BG := Color(0.12, 0.10, 0.16)
const PLAYER_COLOR := Color(0.25, 0.70, 1.00)
const REF_COLOR := Color(0.30, 0.95, 0.50)

## Limb segments drawn as capsules. No head/face links and no fingers — the wrists
## and ankles are the ends of the chains.
const LIMB_BONES := [
	# torso
	["left_shoulder", "right_shoulder"],
	["left_shoulder", "left_hip"],
	["right_shoulder", "right_hip"],
	["left_hip", "right_hip"],
	# arms
	["left_shoulder", "left_elbow"], ["left_elbow", "left_wrist"],
	["right_shoulder", "right_elbow"], ["right_elbow", "right_wrist"],
	# legs
	["left_hip", "left_knee"], ["left_knee", "left_ankle"],
	["right_hip", "right_knee"], ["right_knee", "right_ankle"],
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
	_draw_figure(kp, mapper, PLAYER_COLOR)

func _draw_reference(rect: Rect2) -> void:
	if choreo == null:
		return
	var pose := choreo.reference_pose(current_index)
	var mapper := _make_mapper(REF_W, REF_H, rect, false)
	_draw_figure(pose, mapper, REF_COLOR)

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

func _draw_figure(pose: Dictionary, mapper: Callable, color: Color) -> void:
	var width := _limb_width(pose, mapper)
	var outline := color.darkened(0.4)

	# Limbs as capsules.
	for bone in LIMB_BONES:
		if _valid(pose, bone[0]) and _valid(pose, bone[1]):
			_capsule(mapper.call(pose[bone[0]]), mapper.call(pose[bone[1]]), width, color)

	# Neck: connect the shoulders to the head so it doesn't float.
	var head := _head_geometry(pose, mapper, width)
	if head["has"] and _valid(pose, "left_shoulder") and _valid(pose, "right_shoulder"):
		var shoulder_mid: Vector2 = (mapper.call(pose["left_shoulder"]) + mapper.call(pose["right_shoulder"])) * 0.5
		_capsule(shoulder_mid, head["center"], width, color)

	# Head: a circle proportional to the ear-to-ear distance.
	if head["has"]:
		draw_circle(head["center"], head["radius"] + maxf(3.0, width * 0.25), outline)
		draw_circle(head["center"], head["radius"], color)

## A capsule = thick line + a filled circle at each end (rounded caps / joints).
func _capsule(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, color, width, true)
	var r := width * 0.55
	draw_circle(a, r, color)
	draw_circle(b, r, color)

## Limb thickness derived from the on-screen shoulder width so it looks right at
## any figure scale; falls back to a sensible constant if shoulders are missing.
func _limb_width(pose: Dictionary, mapper: Callable) -> float:
	if _valid(pose, "left_shoulder") and _valid(pose, "right_shoulder"):
		var d: float = mapper.call(pose["left_shoulder"]).distance_to(mapper.call(pose["right_shoulder"]))
		return clampf(d * 0.22, 8.0, 40.0)
	return 14.0

## Head circle centre + radius. Prefers the ear midpoint with a radius proportional
## to the ear distance; falls back to the nose, then skips if neither is available.
func _head_geometry(pose: Dictionary, mapper: Callable, width: float) -> Dictionary:
	if _valid(pose, "left_ear") and _valid(pose, "right_ear"):
		var a: Vector2 = mapper.call(pose["left_ear"])
		var b: Vector2 = mapper.call(pose["right_ear"])
		var radius := maxf(a.distance_to(b) * 0.6, width * 1.2)
		return {"has": true, "center": (a + b) * 0.5, "radius": radius}
	if _valid(pose, "nose"):
		var radius := width * 1.6
		if _valid(pose, "left_shoulder") and _valid(pose, "right_shoulder"):
			radius = maxf(mapper.call(pose["left_shoulder"]).distance_to(mapper.call(pose["right_shoulder"])) * 0.35, width * 1.2)
		return {"has": true, "center": mapper.call(pose["nose"]), "radius": radius}
	return {"has": false, "center": Vector2.ZERO, "radius": 0.0}

## A keypoint is shown only if it's present, not at the origin (YOLO reports (0,0)
## for undetected joints), and — when confidence is available — above the threshold.
## Reference poses from dance.json have no "c" field and are always considered valid.
func _valid(pose: Dictionary, part: String) -> bool:
	if not pose.has(part):
		return false
	var p = pose[part]
	if int(p["x"]) == 0 and int(p["y"]) == 0:
		return false
	if p.has("c") and float(p["c"]) < CONF_THRESHOLD:
		return false
	return true
