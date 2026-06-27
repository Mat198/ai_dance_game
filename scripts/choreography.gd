class_name Choreography
extends RefCounted
## Loads the dance from res://choreography/dance.json and owns move timing + scoring.
## This is the GDScript port of the Python game/choreography.py and game/geometry.py.

const DANCE_PATH := "res://choreography/dance.json"

## Scoring compares the image-plane *orientation* of each limb segment between the
## player and the reference, measured relative to the shoulder line (so it's
## invariant to where the player stands, how far from the camera, and small body
## rotation/lean). A bone counts only if all its joints are valid in BOTH poses,
## so legs/hips participate when visible and are skipped otherwise.
##
## The shoulder line itself is the reference axis, so it is not in this list.
## Each pair is the vector a -> b.
const SCORE_BONES := [
	# arms
	["left_shoulder", "left_elbow"], ["left_elbow", "left_wrist"],
	["right_shoulder", "right_elbow"], ["right_elbow", "right_wrist"],
	# torso sides + hip line
	["left_shoulder", "left_hip"], ["right_shoulder", "right_hip"],
	["left_hip", "right_hip"],
	# legs
	["left_hip", "left_knee"], ["left_knee", "left_ankle"],
	["right_hip", "right_knee"], ["right_knee", "right_ankle"],
]

# A joint must be at least this confident (when confidence is present) to be scored.
const SCORE_CONF := 0.5
# Angular error (degrees) at which a bone scores 0; linear falloff from a perfect match.
const ANGLE_TOLERANCE_DEG := 40.0
# Need at least this many comparable bones for the frame to produce a score.
const MIN_SCORED_BONES := 3

## Each entry: { "name": String, "time": float, "pose": Dictionary }, sorted by time.
var moves: Array = []

func load_dance() -> bool:
	var f := FileAccess.open(DANCE_PATH, FileAccess.READ)
	if f == null:
		push_error("Choreography: cannot open %s" % DANCE_PATH)
		return false
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_error("Choreography: invalid JSON in %s" % DANCE_PATH)
		return false
	var data: Dictionary = json.data
	for key in data.keys():
		var entry: Dictionary = data[key]
		moves.append({"name": key, "time": float(entry["time"]), "pose": entry["pose"]})
	moves.sort_custom(func(a, b): return a["time"] < b["time"])
	print("Choreography loaded with %d moves" % moves.size())
	return moves.size() > 0

func move_count() -> int:
	return moves.size()

func total_time() -> float:
	if moves.is_empty():
		return 0.0
	return moves[moves.size() - 1]["time"]

## Index of the move that should be displayed at the given elapsed time (seconds).
func active_index(elapsed: float) -> int:
	for i in moves.size():
		if elapsed <= moves[i]["time"]:
			return i
	return moves.size() - 1

func reference_pose(index: int) -> Dictionary:
	return moves[index]["pose"]

## Instantaneous match score in [0, 100] for `player` against move `index`, based
## on per-limb orientation differences. Returns -1.0 when there aren't enough
## comparable bones (e.g. player not detected), so callers can skip the sample.
func score_pose(player: Variant, index: int) -> float:
	if player == null:
		return -1.0
	var ref_pose: Dictionary = moves[index]["pose"]
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
		# Orientation of each bone relative to its own shoulder line.
		var player_rel := _bone_angle(player, a, b) - player_axis
		var ref_rel := _bone_angle(ref_pose, a, b) - ref_axis
		var diff := _angle_diff(player_rel, ref_rel)
		total += maxf(0.0, 1.0 - diff / ANGLE_TOLERANCE_DEG) * 100.0
		count += 1

	if count < MIN_SCORED_BONES:
		return -1.0
	return total / count

## A joint is scorable if present, not at the origin, and (when confidence exists)
## confident enough. Synthesized/low-confidence joints are intentionally excluded.
func _joint_valid(pose: Dictionary, part: String) -> bool:
	if not pose.has(part):
		return false
	var p = pose[part]
	if int(p["x"]) == 0 and int(p["y"]) == 0:
		return false
	if p.has("c") and float(p["c"]) < SCORE_CONF:
		return false
	return true

## Image-plane orientation (degrees) of the vector from joint `a` to joint `b`.
func _bone_angle(pose: Dictionary, a: String, b: String) -> float:
	var dx := float(pose[b]["x"]) - float(pose[a]["x"])
	var dy := float(pose[b]["y"]) - float(pose[a]["y"])
	return rad_to_deg(atan2(dy, dx))

## Reference axis = the shoulder line, used to cancel out whole-body rotation.
## Falls back to absolute (0) orientation if the shoulders aren't both visible.
func _axis_angle(pose: Dictionary) -> float:
	if _joint_valid(pose, "left_shoulder") and _joint_valid(pose, "right_shoulder"):
		return _bone_angle(pose, "left_shoulder", "right_shoulder")
	return 0.0

## Smallest absolute difference between two angles (degrees), in [0, 180].
func _angle_diff(a_deg: float, b_deg: float) -> float:
	var d := fmod(absf(a_deg - b_deg), 360.0)
	if d > 180.0:
		d = 360.0 - d
	return d
