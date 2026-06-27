class_name Choreography
extends RefCounted
## Loads the dance from res://choreography/dance.json and owns move timing + scoring.
## This is the GDScript port of the Python game/choreography.py and game/geometry.py.

const DANCE_PATH := "res://choreography/dance.json"

## Upper-body parts used for scoring (webcam FOV doesn't reliably see legs).
const SCORED_PARTS := [
	"nose", "left_shoulder", "right_shoulder",
	"left_elbow", "right_elbow", "left_wrist", "right_wrist",
]

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

## Score how well `player` keypoints match move `index`. Mirrors the Python
## algorithm: per-part 100/(distance+1), averaged over the scored parts.
func score_pose(player: Variant, index: int) -> int:
	if player == null:
		return 0
	var ref_pose: Dictionary = moves[index]["pose"]
	var total := 0.0
	for part in SCORED_PARTS:
		if not player.has(part) or not ref_pose.has(part):
			continue
		var dx := float(player[part]["x"]) - float(ref_pose[part]["x"])
		var dy := float(player[part]["y"]) - float(ref_pose[part]["y"])
		var dist := sqrt(dx * dx + dy * dy)
		total += 100.0 / (dist + 1.0)
	return int(round(total / SCORED_PARTS.size()))
