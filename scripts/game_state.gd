extends Node
## Autoload singleton holding state that survives scene changes (Menu -> Game -> Results).

var player_count: int = 1
## res:// path of the choreography to play (chosen on the song-select screen);
## "" means use the default.
var choreography_path: String = ""
## Per-player final totals, set by the Game scene and read by the Results scene.
var scores: Array = []
