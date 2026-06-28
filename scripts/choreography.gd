class_name Choreography
extends RefCounted
## The choreography as a time-indexed list of pose keyframes.
##
## Two sources, same model:
##   - res://choreography/dance.csv  : a dense per-frame timeline recorded from a
##                                     dance video (see choreography/extract_video.py)
##   - res://choreography/dance.json : the older sparse keyposes (fallback)
## Either way we end up with keyframes sorted by time and interpolate between them,
## so the reference figure moves continuously instead of snapping between poses.

const TIMELINE_CSV := "res://choreography/dance.csv"
const DANCE_JSON := "res://choreography/dance.json"

## COCO-17 order. MUST match game/keypoints.py KEYPOINT_NAMES and the CSV columns.
const KEYPOINT_NAMES := [
	"nose", "left_eye", "right_eye", "left_ear", "right_ear",
	"left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
	"left_wrist", "right_wrist", "left_hip", "right_hip",
	"left_knee", "right_knee", "left_ankle", "right_ankle",
]

## Scoring compares the image-plane orientation of each limb segment, relative to
## the shoulder line (invariant to position, scale, and small body rotation). A bone
## counts only if its joints are valid in BOTH poses, so legs/hips participate when
## visible and are skipped otherwise. The shoulder line is the axis, not a scored bone.
const SCORE_BONES := [
	["left_shoulder", "left_elbow"], ["left_elbow", "left_wrist"],
	["right_shoulder", "right_elbow"], ["right_elbow", "right_wrist"],
	["left_shoulder", "left_hip"], ["right_shoulder", "right_hip"],
	["left_hip", "right_hip"],
	["left_hip", "left_knee"], ["left_knee", "left_ankle"],
	["right_hip", "right_knee"], ["right_knee", "right_ankle"],
]
const SCORE_CONF := 0.5
const ANGLE_TOLERANCE_DEG := 40.0
const MIN_SCORED_BONES := 3
## Score the player against the best-matching reference pose within +/- this many
## seconds, to forgive human reaction lag and detection latency.
const TIME_TOLERANCE := 0.3

## Sorted [{ "time": float, "pose": Dictionary }].
var keyframes: Array = []
## Resolution the reference poses were captured at, for undistorted rendering.
var ref_width := 640.0
var ref_height := 480.0
## Song this choreography was recorded to (res:// path), or "" to use the default.
var song_path := ""

func load_dance() -> bool:
	if FileAccess.file_exists(TIMELINE_CSV) and _load_csv():
		print("Choreography: loaded %d frames from dance.csv" % keyframes.size())
		return true
	if _load_json():
		print("Choreography: loaded %d keyposes from dance.json" % keyframes.size())
		return true
	push_error("Choreography: no dance.csv or dance.json could be loaded")
	return false

func duration() -> float:
	if keyframes.is_empty():
		return 0.0
	return keyframes[keyframes.size() - 1]["time"]

## Interpolated reference pose at time `t` (seconds), clamped to the timeline ends.
func reference_pose_at(t: float) -> Dictionary:
	var n := keyframes.size()
	if n == 0:
		return {}
	if t <= keyframes[0]["time"]:
		return keyframes[0]["pose"]
	if t >= keyframes[n - 1]["time"]:
		return keyframes[n - 1]["pose"]
	var i := 0
	while i < n - 1 and keyframes[i + 1]["time"] < t:
		i += 1
	var t0: float = keyframes[i]["time"]
	var t1: float = keyframes[i + 1]["time"]
	var frac := 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
	return _lerp_pose(keyframes[i]["pose"], keyframes[i + 1]["pose"], frac)

## Best instantaneous match in [0, 100] for `player` around time `t`, or -1 when
## there aren't enough comparable bones (e.g. player not detected).
func score_at(player: Variant, t: float) -> float:
	if player == null:
		return -1.0
	var best := -1.0
	for off in [-TIME_TOLERANCE, -TIME_TOLERANCE * 0.5, 0.0, TIME_TOLERANCE * 0.5, TIME_TOLERANCE]:
		var s := _score_against(player, reference_pose_at(t + off))
		if s > best:
			best = s
	return best

# --- loading --------------------------------------------------------------------

func _load_csv() -> bool:
	var f := FileAccess.open(TIMELINE_CSV, FileAccess.READ)
	if f == null:
		return false
	# Parsed manually (not get_csv_line) so a song path containing commas survives
	# in the metadata comment lines; data rows have no commas in their fields.
	var fps := 15.0
	var row := 0
	for raw in f.get_as_text().split("\n"):
		var line := raw.strip_edges()
		if line == "":
			continue
		if line.begins_with("#"):
			fps = _apply_meta(line, fps)
			continue
		var cells := line.split(",")
		if cells.size() == 0 or not cells[0].is_valid_float():
			continue  # column-name header row
		keyframes.append({"time": row / fps, "pose": _row_to_pose(cells)})
		row += 1
	return keyframes.size() > 0

func _apply_meta(line: String, fps: float) -> float:
	# Either "# fps=15 width=1280 height=720" or "# song=res://songs/My Song.mp3"
	# (song kept whole so commas/spaces in the filename are preserved).
	var body := line.trim_prefix("#").strip_edges()
	if body.begins_with("song="):
		song_path = body.substr(5).strip_edges()
		return fps
	for token in body.split(" ", false):
		var kv := token.split("=")
		if kv.size() == 2 and kv[1].is_valid_float():
			match kv[0]:
				"fps": fps = float(kv[1])
				"width": ref_width = float(kv[1])
				"height": ref_height = float(kv[1])
	return fps

func _row_to_pose(cells: PackedStringArray) -> Dictionary:
	var pose := {}
	for k in KEYPOINT_NAMES.size():
		var base := k * 3
		if base + 2 >= cells.size():
			break
		pose[KEYPOINT_NAMES[k]] = {
			"x": int(cells[base]),
			"y": int(cells[base + 1]),
			"c": float(cells[base + 2]),
		}
	return pose

func _load_json() -> bool:
	var f := FileAccess.open(DANCE_JSON, FileAccess.READ)
	if f == null:
		return false
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return false
	var data: Dictionary = json.data
	for key in data.keys():
		var entry: Dictionary = data[key]
		keyframes.append({"time": float(entry["time"]), "pose": entry["pose"]})
	keyframes.sort_custom(func(a, b): return a["time"] < b["time"])
	ref_width = 640.0
	ref_height = 480.0
	return keyframes.size() > 0

func _lerp_pose(a: Dictionary, b: Dictionary, frac: float) -> Dictionary:
	var out := {}
	for name in a.keys():
		if b.has(name):
			var pa = a[name]
			var pb = b[name]
			out[name] = {
				"x": lerpf(float(pa["x"]), float(pb["x"]), frac),
				"y": lerpf(float(pa["y"]), float(pb["y"]), frac),
				"c": lerpf(float(pa.get("c", 1.0)), float(pb.get("c", 1.0)), frac),
			}
		else:
			out[name] = a[name]
	return out

# --- scoring --------------------------------------------------------------------

func _score_against(player: Variant, ref_pose: Dictionary) -> float:
	if ref_pose.is_empty():
		return -1.0
	var player_axis := _axis_angle(player)
	var ref_axis := _axis_angle(ref_pose)
	var total := 0.0
	var count := 0
	for bone in SCORE_BONES:
		var a: String = bone[0]
		var b: String = bone[1]
		if not (_joint_valid(player, a) and _joint_valid(player, b) \
				and _joint_valid(ref_pose, a) and _joint_valid(ref_pose, b)):
			continue
		var player_rel := _bone_angle(player, a, b) - player_axis
		var ref_rel := _bone_angle(ref_pose, a, b) - ref_axis
		total += maxf(0.0, 1.0 - _angle_diff(player_rel, ref_rel) / ANGLE_TOLERANCE_DEG) * 100.0
		count += 1
	if count < MIN_SCORED_BONES:
		return -1.0
	return total / count

func _joint_valid(pose: Dictionary, part: String) -> bool:
	if not pose.has(part):
		return false
	var p = pose[part]
	if int(p["x"]) == 0 and int(p["y"]) == 0:
		return false
	if p.has("c") and float(p["c"]) < SCORE_CONF:
		return false
	return true

func _bone_angle(pose: Dictionary, a: String, b: String) -> float:
	var dx := float(pose[b]["x"]) - float(pose[a]["x"])
	var dy := float(pose[b]["y"]) - float(pose[a]["y"])
	return rad_to_deg(atan2(dy, dx))

func _axis_angle(pose: Dictionary) -> float:
	if _joint_valid(pose, "left_shoulder") and _joint_valid(pose, "right_shoulder"):
		return _bone_angle(pose, "left_shoulder", "right_shoulder")
	return 0.0

func _angle_diff(a_deg: float, b_deg: float) -> float:
	var d := fmod(absf(a_deg - b_deg), 360.0)
	if d > 180.0:
		d = 360.0 - d
	return d
