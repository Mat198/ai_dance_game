extends Node
## Autoload singleton holding state that survives scene changes (Menu -> Game -> Results).

var player_count: int = 1
## Per-player final totals, set by the Game scene and read by the Results scene.
var scores: Array = []
