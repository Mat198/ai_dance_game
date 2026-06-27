class_name PoseOverlay
extends Node2D
## Draws the live player(s) and the shared choreography as stick figures.
##
## Layout (top to bottom): a thin reserved strip for the progress bar, then one or
## two player panels side by side, then the shared reference panel.
##
## Each figure is a circular head (sized from the ear-to-ear distance) plus capsule
## limbs. Poses are fit into their panel with a uniform scale (preserving aspect
## ratio), so webcam and reference resolutions can differ without distortion.

const WINDOW_W := 1280.0
const WINDOW_H := 1440.0
# Reserved strip at the top for the progress bar (drawn by game.gd).
const TOP_MARGIN := 28.0
# Player panels take the top half of the remaining space; the reference takes the rest.
const PLAYER_ROW_H := (WINDOW_H - TOP_MARGIN) * 0.5

# Resolution the reference poses were captured at (see create_choreography.py).
const REF_W := 640.0
const REF_H := 480.0

# Joints below this detection confidence are hidden (e.g. legs out of frame, which
# YOLO still guesses at a low-confidence random position).
const CONF_THRESHOLD := 0.5
# Hips are torso anchors: keep showing them at lower confidence so the trunk
# doesn't collapse into a floating shoulder bar.
const HIP_CONF_THRESHOLD := 0.2
const HIP_PARTS := ["left_hip", "right_hip"]

const PLAYER_BG := Color(0.10, 0.12, 0.18)
const REF_BG := Color(0.12, 0.10, 0.16)
const PLAYER_COLORS := [Color(0.25, 0.70, 1.00), Color(1.00, 0.55, 0.20)]
const REF_COLOR := Color(0.30, 0.95, 0.50)
const DIVIDER := Color(1, 1, 1, 0.25)

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

## Body joints (head is handled separately via the ears/nose).
const JOINT_PARTS := [
	"left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
	"left_wrist", "right_wrist", "left_hip", "right_hip",
	"left_knee", "right_knee", "left_ankle", "right_ankle",
]

var choreo: Choreography
var current_index := 0
var player_count := 1

func _draw() -> void:
	var rects := player_rects(player_count)
	var ref_rect := reference_rect()
	for r in rects:
		draw_rect(r, PLAYER_BG)
	draw_rect(ref_rect, REF_BG)

	# Divider between the two player panels, and between players and the reference.
	if rects.size() == 2:
		draw_line(Vector2(WINDOW_W * 0.5, TOP_MARGIN), Vector2(WINDOW_W * 0.5, TOP_MARGIN + PLAYER_ROW_H), DIVIDER, 2.0)
	draw_line(Vector2(0, ref_rect.position.y), Vector2(WINDOW_W, ref_rect.position.y), DIVIDER, 2.0)

	# Players (mirrored, selfie-style), each in its own panel.
	var players: Array = VisionClient.players
	var sw := float(VisionClient.source_width)
	var sh := float(VisionClient.source_height)
	if sw > 0.0 and sh > 0.0:
		for i in rects.size():
			if i < players.size() and players[i] != null:
				var mapper := _make_mapper(sw, sh, rects[i], true)
				_draw_figure(players[i], mapper, PLAYER_COLORS[i % PLAYER_COLORS.size()], sh)

	# Shared reference pose.
	if choreo != null:
		var ref_mapper := _make_mapper(REF_W, REF_H, ref_rect, false)
		_draw_figure(choreo.reference_pose(current_index), ref_mapper, REF_COLOR, REF_H)

## Rectangles for each player panel (1 = full width, 2 = side by side).
func player_rects(count: int) -> Array:
	if count >= 2:
		var half := WINDOW_W * 0.5
		return [
			Rect2(0, TOP_MARGIN, half, PLAYER_ROW_H),
			Rect2(half, TOP_MARGIN, half, PLAYER_ROW_H),
		]
	return [Rect2(0, TOP_MARGIN, WINDOW_W, PLAYER_ROW_H)]

func reference_rect() -> Rect2:
	var y := TOP_MARGIN + PLAYER_ROW_H
	return Rect2(0, y, WINDOW_W, WINDOW_H - y)

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

func _draw_figure(pose: Dictionary, mapper: Callable, color: Color, native_h: float) -> void:
	var width := _limb_width(pose, mapper)
	var outline := color.darkened(0.4)

	# Resolve drawable joint positions (screen space) for valid detections.
	var joints := {}
	for part in JOINT_PARTS:
		if _valid(pose, part):
			joints[part] = mapper.call(pose[part])

	# If a hip is missing, synthesize it straight below the shoulder near the
	# bottom of the frame so the torso still reads as a body instead of collapsing.
	_ensure_hip(joints, pose, mapper, native_h, "left_hip", "left_shoulder")
	_ensure_hip(joints, pose, mapper, native_h, "right_hip", "right_shoulder")

	# Limbs as capsules.
	for bone in LIMB_BONES:
		if joints.has(bone[0]) and joints.has(bone[1]):
			_capsule(joints[bone[0]], joints[bone[1]], width, color)

	# Neck: connect the shoulders to the head so it doesn't float.
	var head := _head_geometry(pose, mapper, width)
	if head["has"] and joints.has("left_shoulder") and joints.has("right_shoulder"):
		var shoulder_mid: Vector2 = (joints["left_shoulder"] + joints["right_shoulder"]) * 0.5
		_capsule(shoulder_mid, head["center"], width, color)

	# Head: a circle proportional to the ear-to-ear distance.
	if head["has"]:
		draw_circle(head["center"], head["radius"] + maxf(3.0, width * 0.25), outline)
		draw_circle(head["center"], head["radius"], color)

## Fills in a missing hip joint by dropping a vertical line from the shoulder to
## near the bottom of the frame (97% down). Synthesized in native coordinates so the
## mapper's mirroring keeps it directly under the shoulder.
func _ensure_hip(joints: Dictionary, pose: Dictionary, mapper: Callable, native_h: float, hip: String, shoulder: String) -> void:
	if joints.has(hip) or not joints.has(shoulder):
		return
	var shoulder_x := float(pose[shoulder]["x"])
	joints[hip] = mapper.call({"x": shoulder_x, "y": native_h * 0.97})

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
	if p.has("c"):
		var threshold: float = HIP_CONF_THRESHOLD if part in HIP_PARTS else CONF_THRESHOLD
		if float(p["c"]) < threshold:
			return false
	return true
